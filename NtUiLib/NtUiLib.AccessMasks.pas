unit NtUiLib.AccessMasks;

interface

uses
  Winapi.WinNt, NtUtils.Exceptions;

// Prepare a textial representation of an access mask
function FormatAccess(Access: TAccessMask; MaskType: PAccessMaskType): String;

// Prepare a textial representation of an access mask with a Hex prefix
function FormatAccessPrefixed(Access: TAccessMask; MaskType: PAccessMaskType)
  : String;

implementation

uses
  DelphiUiLib.Strings, System.SysUtils;

function MapFlagRefs(Value: Cardinal; MaskType: PAccessMaskType): String;
var
  Strings: array of String;
  i, Count: Integer;
begin
  SetLength(Strings, MaskType.Count);

  Count := 0;
  for i := 0 to MaskType.Count - 1 do
    if Value and MaskType.Mapping{$R-}[i]{$R+}.Value <> 0 then
    begin
      Strings[Count] := String(MaskType.Mapping{$R-}[i]{$R+}.Name);
      Inc(Count);
    end;

  SetLength(Strings, Count);

  if Count = 0 then
    Result := ''
  else
    Result := String.Join(', ', Strings);
end;

procedure ExcludeFlags(var Value: TAccessMask; MaskType: PAccessMaskType);
var
  i: Integer;
begin
  for i := 0 to MaskType.Count - 1 do
    Value := Value and not MaskType.Mapping{$R-}[i]{$R+}.Value;
end;

procedure ConcatFlags(var Result: String; NewFlags: String);
begin
  if (Result <> '') and (NewFlags <> '') then
    Result := Result + ', ' + NewFlags
  else if NewFlags <> '' then
    Result := NewFlags;
end;

function FormatAccess(Access: TAccessMask; MaskType: PAccessMaskType): String;
var
  i: Integer;
begin
  if Access = 0 then
    Exit('No access');

  Result := '';

  if not Assigned(MaskType) then
    MaskType := @NonSpecificAccessType;

  // Map and exclude full access
  if Access and MaskType.FullAccess <> 0 then
  begin
    Result := 'Full access';
    Access := Access and not MaskType.FullAccess;

    if Access = 0 then
      Exit;
  end;

  // Map and exclude type-specific access
  ConcatFlags(Result, MapFlagRefs(Access, MaskType));
  ExcludeFlags(Access, MaskType);

  if Access = 0 then
    Exit;

  // Map and exclude standard, generic, and other access rights
  ConcatFlags(Result, MapFlagRefs(Access, @NonSpecificAccessType));
  ExcludeFlags(Access, @NonSpecificAccessType);

  if Access = 0 then
    Exit;

  // Map unknown and reserved bits as hex values
  for i := 0 to 31 do
    if Access and (1 shl i) <> 0 then
      ConcatFlags(Result, IntToHexEx(1 shl i, 6));
end;

function FormatAccessPrefixed(Access: TAccessMask; MaskType: PAccessMaskType)
  : String;
begin
  Result := IntToHexEx(Access, 6) + ' (' + FormatAccess(Access, MaskType) + ')';
end;

end.