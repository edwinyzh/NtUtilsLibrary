unit Ntapi.ntcsrapi;

{
  This module includes definitions for sending messages to CSRSS from Native API
}

interface

{$MINENUMSIZE 4}

uses
  Ntapi.WinNt, Ntapi.ntdef, Ntapi.ntlpcapi, Ntapi.ntrtl, Ntapi.ntpebteb,
  DelphiApi.Reflection;

const
  // private
  BASESRV_SERVERDLL_INDEX = 1;

  // rev, bits in process & thread handles for process creation events
  BASE_CREATE_PROCESS_MSG_PROCESS_FLAG_FEEDBACK_ON = $1;
  BASE_CREATE_PROCESS_MSG_PROCESS_FLAG_GUI_WAIT = $2;
  BASE_CREATE_PROCESS_MSG_THREAD_FLAG_CROSS_SESSION = $1;
  BASE_CREATE_PROCESS_MSG_THREAD_FLAG_PROTECTED_PROCESS = $2;

  // private, VDM binary types
  BINARY_TYPE_DOS = $10;
  BINARY_TYPE_WIN16 = $20;
  BINARY_TYPE_SEPWOW = $40;
  BINARY_SUBTYPE_MASK = $0F;
  BINARY_TYPE_DOS_EXE = $01;
  BINARY_TYPE_DOS_COM = $02;
  BINARY_TYPE_DOS_PIF = $03;

  // private, CreateProcess SxS message flags
  BASE_MSG_SXS_MANIFEST_PRESENT = $0001;
  BASE_MSG_SXS_POLICY_PRESENT = $0002;
  BASE_MSG_SXS_SYSTEM_DEFAULT_TEXTUAL_ASSEMBLY_IDENTITY_PRESENT = $0004;
  BASE_MSG_SXS_TEXTUAL_ASSEMBLY_IDENTITY_PRESENT = $0008;
  BASE_MSG_SXS_NO_ISOLATION_CHARACTERISTICS_PRESENT = $0020; // rev
  BASE_MSG_SXS_EMBEDDED_MANIFEST_PRESENT = $0040; // rev
  BASE_MSG_SXS_DEV_OVERRIDE_PRESENT = $0080; // rev
  BASE_MSG_SXS_MANIFEST_OVERRIDE_PRESENT = $0100; // rev
  BASE_MSG_SXS_PACKAGE_IDENTITY_PRESENT = $0400; // rev
  BASE_MSG_SXS_FULL_TRUST_INTEGRITY_PRESENT = $0800; // rev

  // rev
  DEFAULT_LANGUAGE_FALLBACK: String = 'en-US'#0#0#0#0#0;

  // SDK::WinBase.h - shutdown parameters flags
  SHUTDOWN_NORETRY = $00000001;

  // SDK::WinBase.h - DOS device flags
  DDD_RAW_TARGET_PATH = $00000001;
  DDD_REMOVE_DEFINITION = $00000002;
  DDD_EXACT_MATCH_ON_REMOVE = $00000004;
  DDD_NO_BROADCAST_SYSTEM = $00000008;
  DDD_LUID_BROADCAST_DRIVE = $00000010;

type
  [SDKName('CSR_API_NUMBER')]
  TCsrApiNumber = type Cardinal;

  PCsrCaptureHeader = ^TCsrCaptureHeader;

  [SDKName('CSR_CAPTURE_HEADER')]
  TCsrCaptureHeader = record
    Length: Cardinal;
    RelatedCaptureBuffer: PCsrCaptureHeader;
    CountMessagePointers: Cardinal;
    FreeSpace: Pointer;
    MessagePointerOffsets: TAnysizeArray<NativeUInt>;
  end;

  [SDKName('CSR_API_MSG')]
  TCsrApiMsg = record
    h: TPortMessage;
    CaptureBuffer: PCsrCaptureHeader;
    ApiNumber: TCsrApiNumber;
    ReturnValue: NTSTATUS;
    [Reserved] Reserved: Cardinal;
    ApiMessageData: TPlaceholder;
  end;
  PCsrApiMsg = ^TCsrApiMsg;
  PPCsrApiMsg = ^PCsrApiMsg;

  [SDKName('BASESRV_API_NUMBER')]
  [NamingStyle(nsCamelCase, 'Basep'), ValidMask($7EFFFFE1)]
  TBaseSrvApiNumber = (
    BasepCreateProcess = $0,
    [Reserved] BasepDeadEntry1 = $1,
    [Reserved] BasepDeadEntry2 = $2,
    [Reserved] BasepDeadEntry3 = $3,
    [Reserved] BasepDeadEntry4 = $4,
    BasepCheckVDM = $5,
    BasepUpdateVDMEntry = $6,
    BasepGetNextVDMCommand = $7,
    BasepExitVDM = $8,
    BasepIsFirstVDM = $9,
    BasepGetVDMExitCode = $A,
    BasepSetReenterCount = $B,
    BasepSetProcessShutdownParam = $C,   // in: TBaseShutdownParamMsg
    BasepGetProcessShutdownParam = $D,   // out: TBaseShutdownParamMsg
    BasepSetVDMCurDirs = $E,
    BasepGetVDMCurDirs = $F,
    BasepBatNotification = $10,
    BasepRegisterWowExec = $11,
    BasepSoundSentryNotification = $12,
    BasepRefreshIniFileMapping = $13,
    BasepDefineDosDevice = $14,          // in: TBaseDefineDosDeviceMsg
    BasepSetTermsrvAppInstallMode = $15,
    BasepSetTermsrvClientTimeZone = $16,
    BasepCreateActivationContext = $17,
    [Reserved] BasepDeadEntry24 = $18,
    BasepRegisterThread = $19,
    BasepDeferredCreateProcess = $1A,
    BasepNlsGetUserInfo = $1B,
    BasepNlsUpdateCacheCount = $1C,
    BasepCreateProcess2 = $1D,           // Win 10 20H1+
    BasepCreateActivationContext2 = $1E
  );

  { API number 0x00 & 0x1D }

  [FlagName(BINARY_TYPE_DOS, 'DOS')]
  [FlagName(BINARY_TYPE_WIN16, 'Win16')]
  [FlagName(BINARY_TYPE_SEPWOW, 'Separate WoW')]
  [SubEnum(BINARY_SUBTYPE_MASK, BINARY_TYPE_DOS_EXE, 'DOS EXE')]
  [SubEnum(BINARY_SUBTYPE_MASK, BINARY_TYPE_DOS_COM, 'DOS COM')]
  [SubEnum(BINARY_SUBTYPE_MASK, BINARY_TYPE_DOS_PIF, 'DOS PIF')]
  TBaseVdmBinaryType = type Cardinal;

  [FlagName(BASE_MSG_SXS_MANIFEST_PRESENT, 'Manifest Present')]
  [FlagName(BASE_MSG_SXS_POLICY_PRESENT, 'Policy Present')]
  [FlagName(BASE_MSG_SXS_SYSTEM_DEFAULT_TEXTUAL_ASSEMBLY_IDENTITY_PRESENT, 'System Default Textual Assembly Identity Present')]
  [FlagName(BASE_MSG_SXS_TEXTUAL_ASSEMBLY_IDENTITY_PRESENT, 'Textual Assembly Identity Present')]
  [FlagName(BASE_MSG_SXS_NO_ISOLATION_CHARACTERISTICS_PRESENT, 'No Isolation')]
  [FlagName(BASE_MSG_SXS_EMBEDDED_MANIFEST_PRESENT, 'Embedded Manifest Present')]
  TBaseMsgSxsFlags = type Cardinal;

  {$MINENUMSIZE 1}
  [NamingStyle(nsSnakeCase, 'BASE_MSG_FILETYPE')]
  TBaseMsgFileType = (
    BASE_MSG_FILETYPE_NONE = 0,
    BASE_MSG_FILETYPE_XML = 1,
    BASE_MSG_FILETYPE_PRECOMPILED_XML = 2
  );
  {$MINENUMSIZE 4}

  {$MINENUMSIZE 1}
  [NamingStyle(nsSnakeCase, 'BASE_MSG_PATHTYPE')]
  TBaseMsgPathType = (
    BASE_MSG_PATHTYPE_NONE = 0,
    BASE_MSG_PATHTYPE_FILE = 1,
    BASE_MSG_PATHTYPE_URL = 2,
    BASE_MSG_PATHTYPE_OVERRIDE = 3
  );
  {$MINENUMSIZE 4}

  {$MINENUMSIZE 1}
  [NamingStyle(nsSnakeCase, 'BASE_MSG_HANDLETYPE')]
  TBaseMsgHandleType = (
    BASE_MSG_HANDLETYPE_NONE = 0,
    BASE_MSG_HANDLETYPE_PROCESS = 1,
    BASE_MSG_HANDLETYPE_CLIENT_PROCESS = 2,
    BASE_MSG_HANDLETYPE_SECTION = 3
  );
  {$MINENUMSIZE 4}

  [SDKName('BASE_MSG_SXS_STREAM')]
  TBaseMsgSxsStream = record
    FileType: TBaseMsgFileType;
    PathType: TBaseMsgPathType;
    HandleType: TBaseMsgHandleType;
    Path: TNtUnicodeString;
    FileHandle: THandle;
    Handle: THandle;
    Offset: UInt64;
    Size: NativeUInt;
  end;
  PBaseMsgSxsStream = ^TBaseMsgSxsStream;

  // SDK::winnt.h
  [SDKName('ACTCTX_REQUESTED_RUN_LEVEL')]
  [NamingStyle(nsSnakeCase, 'ACTCTX_RUN_LEVEL_')]
  TActCtxRequestedRunLevel = (
    ACTCTX_RUN_LEVEL_UNSPECIFIED = 0,
    ACTCTX_RUN_LEVEL_AS_INVOKER = 1,
    ACTCTX_RUN_LEVEL_HIGHEST_AVAILABLE = 2,
    ACTCTX_RUN_LEVEL_REQUIRE_ADMIN = 3
  );

  // SDK::winnt.h
  [SDKName('ACTIVATION_CONTEXT_RUN_LEVEL_INFORMATION')]
  TActivationContextRunLevelInformation = record
    [Reserved] ulFlags: Cardinal;
    RunLevel: TActCtxRequestedRunLevel;
    UIAccess: LongBool;
  end;
  PActivationContextRunLevelInformation = ^TActivationContextRunLevelInformation;

  { API numbers 0x0C & 0x0D }

  [FlagName(SHUTDOWN_NORETRY, 'No Retry')]
  TShutdownParamFlags = type Cardinal;

  // API number 0xC & 0xD
  [SDKName('BASE_SHUTDOWNPARAM_MSG')]
  TBaseShutdownParamMsg = record
    CsrMessage: TCsrApiMsg; // Embedded for convenience
    ShutdownLevel: Cardinal;
    ShutdownFlags: TShutdownParamFlags;
  end;
  PBaseShutdownParamMsg = ^TBaseShutdownParamMsg;

  {  API number 0x14 }

  [FlagName(DDD_RAW_TARGET_PATH, 'Raw Target Path')]
  [FlagName(DDD_REMOVE_DEFINITION, 'Remove Definition')]
  [FlagName(DDD_EXACT_MATCH_ON_REMOVE, 'Exact Match On Remove')]
  [FlagName(DDD_NO_BROADCAST_SYSTEM, 'No Broadcast System')]
  [FlagName(DDD_LUID_BROADCAST_DRIVE, 'LUID Broadcast Drive')]
  TDefineDosDeviceFlags = type Cardinal;

  // API number 0x14
  [SDKName('BASE_DEFINEDOSDEVICE_MSG')]
  TBaseDefineDosDeviceMsg = record
    CsrMessage: TCsrApiMsg; // Embedded for convenience
    Flags: TDefineDosDeviceFlags;
    DeviceName: TNtUnicodeString;
    TargetPath: TNtUnicodeString;
  end;
  PBaseDefineDosDeviceMsg = ^TBaseDefineDosDeviceMsg;

  { API number 0x1D }

  // private + rev
  [SDKName('BASE_SXS_CREATEPROCESS_MSG2')]
  TBaseSxsCreateProcessMsg2 = record
    SxsFlags: TBaseMsgSxsFlags;
    CurrentParameterFlags: TRtlUserProcessFlags;
    Manifest: TBaseMsgSxsStream;
    Policy: TBaseMsgSxsStream;
    AssemblyDirectory: TNtUnicodeString;
    LanguageFallback: TNtUnicodeString;  // "en-US" in a 20-byte buffer
    RunLevelInfo: TActivationContextRunLevelInformation;
    SwitchBackManifest: Word;
    [Unlisted] Padding: Word;
    InstallerDetectName: TNtUnicodeString;
    Unknown68: array [0..67] of Cardinal; // TODO: support for V1 message
  end;
  PBaseSxsCreateProcessMsg2 = ^TBaseSxsCreateProcessMsg2;

  // private + rev
  [SDKName('BASE_CREATEPROCESS_MSG2')]
  TBaseCreateProcessMsg2 = record
    CsrMessage: TCsrApiMsg; // Embedded for convenience
    ProcessHandle: THandle; // mixed with BASE_CREATE_PROCESS_MSG_PROCESS_*
    ThreadHandle: THandle;  // mixed with BASE_CREATE_PROCESS_MSG_THREAD_*
    ClientID: TClientId;
    CreationFlags: Cardinal;
    VdmBinaryType: TBaseVdmBinaryType;
    VdmTask: Cardinal;
    hVDM: TProcessId;
    Sxs: TBaseSxsCreateProcessMsg2; // TODO: add alternative form for SxS flag 0x40
    PebAddressNative: Pointer;
    PebAddressWow64: Pointer;
    ProcessorArchitecture: TProcessorArchitecture;
    [Unlisted] Padding: Cardinal;
  end;
  PBaseCreateProcessMsg2 = ^TBaseCreateProcessMsg2;

[SDKName('CSR_MAKE_API_NUMBER')]
function CsrMakeApiNumber(
  DllIndex: Word;
  ApiIndex: Word
): TCsrApiNumber;

function CsrGetProcessId(
): TProcessId; stdcall external ntdll;

[Result: Allocates('CsrFreeCaptureBuffer')]
function CsrAllocateCaptureBuffer(
  [in] CountMessagePointers: Cardinal;
  [in] Size: Cardinal
): PCsrCaptureHeader; stdcall external ntdll;

procedure CsrFreeCaptureBuffer(
  [in] CaptureBuffer: PCsrCaptureHeader
); stdcall external ntdll;

[Result: Counter(ctBytes)]
function CsrAllocateMessagePointer(
  [in, out] CaptureBuffer: PCsrCaptureHeader;
  [Counter(ctBytes)] Length: Cardinal;
  out MessagePointer: Pointer
): Cardinal; stdcall; external ntdll;

procedure CsrCaptureMessageBuffer(
  [in, out] CaptureBuffer: PCsrCaptureHeader;
  [in, opt] Buffer: Pointer;
  Length: Cardinal;
  out CapturedBuffer: Pointer
); stdcall; external ntdll;

procedure CsrCaptureMessageString(
  [in, out] CaptureBuffer: PCsrCaptureHeader;
  StringData: PWideChar;
  [Counter(ctBytes)] Length: Cardinal;
  [Counter(ctBytes)] MaximumLength: Cardinal;
  out CapturedString: TNtUnicodeString // Can also be TNtAnsiString
); stdcall; external ntdll;

function CsrCaptureMessageMultiUnicodeStringsInPlace(
  [Allocates('CsrFreeCaptureBuffer')] var CaptureBuffer: PCsrCaptureHeader;
  NumberOfStringsToCapture: Cardinal;
  const StringsToCapture: TArray<PNtUnicodeString>
): NTSTATUS; stdcall; external ntdll;

function CsrClientCallServer(
  var m: TCsrApiMsg;
  [in, out, opt] CaptureBuffer: PCsrCaptureHeader;
  ApiNumber: TCsrApiNumber;
  ArgLength: Cardinal
): NTSTATUS; stdcall; external ntdll;

function CsrClientConnectToServer(
  [in] ObjectDirectory: PWideChar;
  ServertDllIndex: Cardinal;
  [in, opt] ConnectionInformation: Pointer;
  ConnectionInformationLength: Cardinal;
  [out, opt] CalledFromServer: PBoolean
): NTSTATUS; stdcall; external ntdll;

// PHNT::ntrtl.h
function RtlRegisterThreadWithCsrss(
): NTSTATUS; stdcall; external ntdll;

implementation

function CsrMakeApiNumber;
begin
  Result := (DllIndex shl 16) or ApiIndex;
end;

end.