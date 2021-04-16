unit NtUtils.Shellcode;

{
  This module includes various helper functions for injecting code into other
  processes and finding exports from known DLLs.
}

interface

uses
  Winapi.WinNt, Ntapi.ntpsapi, NtUtils;

const
  PROCESS_REMOTE_EXECUTE = PROCESS_QUERY_LIMITED_INFORMATION or
    PROCESS_CREATE_THREAD or PROCESS_VM_OPERATION or PROCESS_VM_WRITE;

  DEFAULT_REMOTE_TIMEOUT = 5000 * MILLISEC;

// Copy data & code into the process
function RtlxAllocWriteDataCodeProcess(
  hxProcess: IHandle;
  const Data: TMemory;
  out RemoteData: IMemory;
  const Code: TMemory;
  out RemoteCode: IMemory;
  EnsureWoW64Accessible: Boolean = False
): TNtxStatus;

// Wait for a thread & forward it exit status. If the wait times out, prevent
// the memory from automatic deallocation (the thread might still use it).
function RtlxSyncThread(
  hThread: THandle;
  StatusLocation: String;
  Timeout: Int64 = NT_INFINITE;
  MemoryToCapture: TArray<IMemory> = nil
): TNtxStatus;

// Check if a thread wait timed out
function RtlxThreadSyncTimedOut(
  const Status: TNtxStatus
): Boolean;

// Copy the code into the target, execute it, and wait for completion
function RtlxRemoteExecute(
  hxProcess: IHandle;
  const Code: TMemory;
  const Context: TMemory;
  StatusLocation: String;
  TargetIsWow64: Boolean = False;
  Timeout: Int64 = DEFAULT_REMOTE_TIMEOUT
): TNtxStatus;

{ Export location }

// Locate multiple exports in a known dll
function RtlxFindKnownDllExports(
  DllName: String;
  TargetIsWoW64: Boolean;
  Names: TArray<AnsiString>;
  out Addresses: TArray<Pointer>
): TNtxStatus;

// Locate a single export in a known dll
function RtlxFindKnownDllExport(
  DllName: String;
  TargetIsWoW64: Boolean;
  Name: AnsiString;
  out Address: Pointer
): TNtxStatus;

implementation

uses
  Ntapi.ntdef, Ntapi.ntstatus, Ntapi.ntmmapi, NtUtils.Processes.Memory,
  NtUtils.Threads, NtUtils.Ldr, NtUtils.ImageHlp, NtUtils.Sections,
  NtUtils.Synchronization, NtUtils.Processes;

function RtlxAllocWriteDataCodeProcess;
begin
  // Copy RemoteData into the process
  Result := NtxAllocWriteMemoryProcess(hxProcess, Data, RemoteData,
    EnsureWoW64Accessible);

  // Copy RemoteCode into the process
  if Result.IsSuccess then
    Result := NtxAllocWriteExecMemoryProcess(hxProcess, Code, RemoteCode,
      EnsureWoW64Accessible);

  // Undo allocations on failure
  if not Result.IsSuccess then
  begin
    RemoteData := nil;
    RemoteCode := nil;
  end;
end;

function RtlxSyncThread;
var
  Info: TThreadBasicInformation;
  i: Integer;
begin
  // Wait for the thread
  Result := NtxWaitForSingleObject(hThread, Timeout);

  // Make timeouts unsuccessful
  if Result.Status = STATUS_TIMEOUT then
  begin
    Result.Status := STATUS_WAIT_TIMEOUT;

    // The thread did't terminate in time. We can't release the memory it uses.
    for i := 0 to High(MemoryToCapture) do
      MemoryToCapture[i].AutoRelease := False;
  end;

  // Get exit status
  if Result.IsSuccess then
    Result := NtxThread.Query(hThread, ThreadBasicInformation, Info);

  // Forward it
  if Result.IsSuccess then
  begin
    Result.Location := StatusLocation;
    Result.Status := Info.ExitStatus;
  end;
end;

function RtlxThreadSyncTimedOut;
begin
  Result := Status.Matches(STATUS_WAIT_TIMEOUT, 'NtWaitForSingleObject')
end;

function RtlxRemoteExecute;
var
  RemoteCode, RemoteContext: IMemory;
  hxThread: IHandle;
begin
  // Allocate and copy everything to the target
  Result := RtlxAllocWriteDataCodeProcess(hxProcess, Context, RemoteContext,
    Code, RemoteCode, TargetIsWow64);

  if not Result.IsSuccess then
    Exit;

  // Create a thread to execute the code
  Result := NtxCreateThread(hxThread, hxProcess.Handle, RemoteCode.Data,
    RemoteContext.Data);

  if not Result.IsSuccess then
    Exit;

  // Synchronize with the thread
  Result := RtlxSyncThread(hxThread.Handle, StatusLocation, Timeout);
end;

function RtlxInferOriginalBaseImage(
  hSection: THandle;
  const MappedMemory: TMemory;
  out Address: Pointer
): TNtxStatus;
var
  Info: TSectionImageInformation;
  NtHeaders: PImageNtHeaders;
begin
  // Determine the intended entrypoint address of the known DLL
  Result := NtxSection.Query(hSection, SectionImageInformation, Info);

  if not Result.IsSuccess then
    Exit;

  // Find the image header where we can lookup the etrypoint offset
  Result := RtlxGetNtHeaderImage(MappedMemory.Address, MappedMemory.Size,
    NtHeaders);

  if not Result.IsSuccess then
    Exit;

  // Calculate the original base address
  Address := PByte(Info.TransferAddress) -
    NtHeaders.OptionalHeader.AddressOfEntryPoint;
end;

function RtlxFindKnownDllExports;
var
  hxSection: IHandle;
  MappedMemory: IMemory;
  BaseAddress: Pointer;
  AllEntries: TArray<TExportEntry>;
  pEntry: PExportEntry;
  i: Integer;
begin
  if TargetIsWoW64 then
    DllName := '\KnownDlls32\' + DllName
  else
    DllName := '\KnownDlls\' + DllName;

  // Open a known dll
  Result := NtxOpenSection(hxSection, SECTION_MAP_READ or SECTION_QUERY,
    DllName);

  if not Result.IsSuccess then
    Exit;

  // Map it
  Result := NtxMapViewOfSection(MappedMemory, hxSection.Handle,
    NtxCurrentProcess, PAGE_READONLY);

  if not Result.IsSuccess then
    Exit;

  // Infer the base address of the DLL that other processes will use
  Result := RtlxInferOriginalBaseImage(hxSection.Handle,
    MappedMemory.Region, BaseAddress);

  if not Result.IsSuccess then
    Exit;

  // Parse the export table
  Result := RtlxEnumerateExportImage(MappedMemory.Data,
    Cardinal(MappedMemory.Size), True, AllEntries);

  if not Result.IsSuccess then
    Exit;

  SetLength(Addresses, Length(Names));

  for i := 0 to High(Names) do
  begin
    pEntry := RtlxFindExportedName(AllEntries, Names[i]);

    if not Assigned(pEntry) or pEntry.Forwards then
    begin
      Result.Location := 'RtlxFindKnownDllExports';
      Result.Status := STATUS_PROCEDURE_NOT_FOUND;
      Exit;
    end;

    Addresses[i] := PByte(BaseAddress) + pEntry.VirtualAddress;
  end;
end;

function RtlxFindKnownDllExport;
var
  Addresses: TArray<Pointer>;
begin
  Result := RtlxFindKnownDllExports(DllName, TargetIsWoW64, [Name], Addresses);

  if Result.IsSuccess then
    Address := Addresses[0];
end;

end.
