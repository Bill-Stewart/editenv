{ Copyright (C) 2020-2025 by Bill Stewart (bstewart at iname.com)

  This program is free software: you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free Software
  Foundation, either version 3 of the License, or (at your option) any later
  version.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
  details.

  You should have received a copy of the GNU General Public License
  along with this program. If not, see https://www.gnu.org/licenses/.

}

program EditEnv;

{$MODE OBJFPC}
{$MODESWITCH UNICODESTRINGS}
{$R *.res}

// wargcv and wgetopts - https://github.com/Bill-Stewart/wargcv/
// WindowsMessages - https://github.com/Bill-Stewart/WindowsMessages/
uses
  windows,
  wargcv,
  wgetopts,
  WindowsMessages,
  WinConsole,
  WinConsoleLineEditor,
  WinEnvironment,
  WinProcess;

const
  PROGRAM_NAME = 'EditEnv';
  PROGRAM_COPYRIGHT = 'Copyright (C) 2020-2025 by Bill Stewart';

type
  TCommandLine = object
    ErrorCode: DWORD;            // <> 0 if error parsing command line
    ErrorMessage: string;        // error message
    AllowedChars: string;        // --allowedchars
    BeginningOfLine: Boolean;    // --beginningofline
    Debug: Boolean;              // --debug
    DisallowChars: string;       // --disallowchars
    EmptyInputAllowed: Boolean;  // --emptyinputallowed
    GetMaxLength: Boolean;       // --getmaxlength
    Help: Boolean;               // --help
    MaxLength: Word;             // --maxlength
    MaskInput: Boolean;          // --maskinput
    MaskChar: Char;              // --maskinput character
    MinLength: Word;             // --minlength
    OvertypeMode: Boolean;       // --overtypemode
    Prompt: string;              // --prompt
    Quiet: Boolean;              // --quiet
    Timeout: Word;               // --timeout
    EnvVarName: string;          // name of env var to edit
    MaxChars: Integer;           // maximum # of characters we can edit
    function IsValidCharList(const S: string): Boolean;
    procedure Parse();
  end;

function IntToStr(const I: Integer): string;
begin
  Str(I, result);
end;

function StrToInt(const S: string; out I: Integer): Boolean;
var
  E: Word;
begin
  Val(S, I, E);
  result := E = 0;
end;

function StringOfChar(const C: Char; const Len: Integer): string;
var
  I: Integer;
begin
  if Len > 0 then
  begin
    SetLength(result, Len);
    for I := 1 to Len do
      result[I] := C;
  end
  else
    result := '';
end;

function GetFileVersion(const FileName: string): string;
var
  VerInfoSize, Handle: DWORD;
  pBuffer: Pointer;
  pFileInfo: ^VS_FIXEDFILEINFO;
  Len: UINT;
begin
  result := '';
  VerInfoSize := GetFileVersionInfoSizeW(PChar(FileName),  // LPCWSTR lptstrFilename
    Handle);                                               // LPDWORD lpdwHandle
  if VerInfoSize > 0 then
  begin
    GetMem(pBuffer, VerInfoSize);
    if GetFileVersionInfoW(PChar(FileName),  // LPCWSTR lptstrFilename
      Handle,                                // DWORD   dwHandle
      VerInfoSize,                           // DWORD   dwLen
      pBuffer) then                          // LPVOID  lpData
    begin
      if VerQueryValueW(pBuffer,  // LPCVOID pBlock
        '\',                      // LPCWSTR lpSubBlock
        pFileInfo,                // LPVOID  *lplpBuffer
        Len) then                 // PUINT   puLen
      begin
        with pFileInfo^ do
        begin
          result := IntToStr(HiWord(dwFileVersionMS)) + '.' +
            IntToStr(LoWord(dwFileVersionMS)) + '.' +
            IntToStr(HiWord(dwFileVersionLS));
        end;
      end;
    end;
    FreeMem(pBuffer, VerInfoSize);
  end;
end;

// Used in Usage() routine to output exit codes and descriptions
procedure WriteEC(const ErrorCode, Width: Integer; const Description: string);
var
  S: string;
  Len: Integer;
begin
  S := IntToStr(ErrorCode);
  Len := Length(S);
  if Len < Width then
    S := S + StringOfChar(' ', Width - Len);
  WriteLn(S + Description);
end;

procedure Usage();
const
  Width: Integer = 11;
begin
  WriteLn(PROGRAM_NAME, ' ', GetFileVersion(ParamStr(0)), ' - ', PROGRAM_COPYRIGHT);
  WriteLn('This is free software and comes with ABSOLUTELY NO WARRANTY.');
  WriteLn();
  WriteLn('SYNOPSIS');
  WriteLn();
  WriteLn('Allows interactive editing of an environment variable in a Windows console.');
  WriteLn();
  WriteLn('USAGE');
  WriteLn();
  WriteLn(PROGRAM_NAME, ' [parameter [...]] variablename');
  WriteLn();
  WriteLn('Parameter            Abbrev.  Description');
  WriteLn('-------------------  -------  -----------');
  WriteLn('--allowedchars=...   -a ...   Only allows input of specified characters');
  WriteLn('--beginningofline    -b       Starts cursor at beginning of line');
  WriteLn('--disallowchars=...  -d ...   Disallows input of specified characters');
  WriteLn('--emptyinputallowed  -e       Empty input is allowed to remove variable');
  WriteLn('--help               -h       Displays usage information');
  WriteLn('--maskinput[=c]      -m c     Masks input using character c (default=*)');
  WriteLn('--minlength=n        -n n     Input must be at least n character(s)');
  WriteLn('--maxlength=n        -x n     Limit input length to n character(s)');
  WriteLn('--overtypemode       -o       Starts line editor in overtype mode');
  WriteLn('--prompt=...         -p ...   Specifies an input prompt');
  WriteLn('--quiet              -q       Suppresses error messages');
  WriteLn('--timeout=n          -t n     Automatically enter input after n second(s)');
  WriteLn();
  WriteLn('Parameter names are case-sensitive.');
  WriteLn();
  WriteLn('LINE EDITOR');
  WriteLn();
  WriteLn('The line editor supports the following keystroke commands:');
  WriteLn();
  WriteLn('Key                     Action');
  WriteLn('---                     ------');
  WriteLn('Left, Right             Moves cursor left or right');
  WriteLn('Home or Ctrl+A          Moves cursor to beginning of line');
  WriteLn('End or Ctrl+E           Moves cursor to end of line');
  WriteLn('Ctrl+Left, Ctrl+Right   Moves cursor left or right one word');
  WriteLn('Insert                  Toggles between insert and overtype mode');
  WriteLn('Delete                  Deletes the character under the cursor');
  WriteLn('Backspace or Ctrl+H     Deletes the character to the left of the cursor');
  WriteLn('Ctrl+Home               Deletes to the beginning of the line');
  WriteLn('Ctrl+End                Deletes to the end of the line');
  WriteLn('Esc or Ctrl+[           Deletes the entire line');
  WriteLn('Ctrl+U or Ctrl+Z        Reverts line to original value');
  WriteLn('Ctrl+V or Shift+Insert  Pastes clipboard text');
  WriteLn('Ctrl+C or Ctrl+Break    Cancels input');
  WriteLn('Enter or Ctrl+M         Enters input');
  WriteLn();
  WriteLn('EXIT CODES');
  WriteLn();
  WriteLn('Exit Code  Description');
  WriteLn('---------  -----------');
  WriteEC(ERROR_SUCCESS,                   Width, 'No error');
  WriteEC(ERROR_INVALID_HANDLE,            Width, 'Does not work from the PowerShell ISE');
  WriteEC(ERROR_INVALID_DATA,              Width, 'Empty input and --emptyinputallowed (-e) not specified');
  WriteEC(ERROR_INVALID_PARAMETER,         Width, 'Command line contains an error');
  WriteEC(ERROR_INSUFFICIENT_BUFFER,       Width, 'Environment variable name or value are too long');
  WriteEC(ERROR_ALREADY_EXISTS,            Width, 'Cannot use --maskinput parameter when variable exists');
  WriteEC(ERROR_EXE_MACHINE_TYPE_MISMATCH, Width, 'Current and parent process must both be 32-bit or 64-bit');
  WriteEC(WAIT_TIMEOUT,                    Width, '--timeout (-t) period elapsed');
  WriteEC(ERROR_CANCELLED,                 Width, 'Ctrl+C or Ctrl+Break pressed to cancel input');
  WriteLn();
  WriteLn('* In cmd.exe, you can check the exit code using the ERRORLEVEL variable or');
  WriteLn('  the if errorlevel command.');
  WriteLn('* In PowerShell, you can check the exit code using the $LASTEXITCODE variable.');
  WriteLn();
  WriteLn('NOTES/LIMITATIONS');
  WriteLn();
  WriteLn('* The environment variable''s name cannot contain the = character');
  WriteLn('* The environment variable''s name is limited to ', MAX_ENVVAR_NAME_LENGTH, ' characters');
  WriteLn('* The --timeout (-t) parameter does not use a high-precision timer');
  WriteLn('* The --maskinput (-m) parameter is not encrypted or secure');
  WriteLn('* There is no visual indication of insert vs. overtype mode');
  WriteLn('* Does not work from the PowerShell ISE');
  WriteLn('* Input length in Windows Terminal is limited to the current screenful');
end;

function TCommandLine.IsValidCharList(const S: string): Boolean;
const
  CtrlChars: array of Char = (#0,#1,#2,#3,#4,#5,
    #6,#7,#8,#9,#10,#11,#12,#13,#14,#15,#16,#17,#18,#19,
    #20,#21,#22,#23,#24,#25,#26,#27,#28,#29,#30,#31,#127);
var
  I: Integer;
begin
  result := true;
  for I := 0 to Length(CtrlChars) - 1 do
  begin
    result := Pos(CtrlChars[I], S) = 0;
    if not result then
      break;
  end;
end;

// Parse the command line
procedure TCommandLine.Parse();
var
  LongOpts: array[1..15] of TOption;
  Opt: Char;
  I, IntArg: Integer;
begin
  // Configure option array (must have final member with empty name)
  with LongOpts[1] do
  begin
    Name := 'allowedchars';
    Has_arg := Required_Argument;
    Flag := nil;
    Value := 'a';
  end;
  with LongOpts[2] do
  begin
    Name := 'beginningofline';
    Has_arg := No_Argument;
    Flag := nil;
    Value := 'b';
  end;
  with LongOpts[3] do
  begin
    Name := 'debug';
    Has_arg := No_Argument;
    Flag := nil;
    Value := #0;
  end;
  with LongOpts[4] do
  begin
    Name := 'disallowchars';
    Has_arg := Required_Argument;
    Flag := nil;
    Value := 'd';
  end;
  with LongOpts[5] do
  begin
    Name := 'emptyinputallowed';
    Has_arg := No_Argument;
    Flag := nil;
    Value := 'e';
  end;
  with LongOpts[6] do
  begin
    Name := 'getmaxlength';
    Has_arg := No_Argument;
    Flag := nil;
    Value := #0;
  end;
  with LongOpts[7] do
  begin
    Name := 'help';
    Has_arg := No_Argument;
    Flag := nil;
    Value := 'h';
  end;
  with LongOpts[8] do
  begin
    Name := 'maskinput';
    Has_arg := Optional_Argument;
    Flag := nil;
    Value := 'm';
  end;
  with LongOpts[9] do
  begin
    Name := 'maxlength';
    Has_arg := Required_Argument;
    Flag := nil;
    Value := 'x';
  end;
  with LongOpts[10] do
  begin
    Name := 'minlength';
    Has_arg := Required_Argument;
    Flag := nil;
    Value := 'n';
  end;
  with LongOpts[11] do
  begin
    Name := 'overtypemode';
    Has_arg := No_Argument;
    Flag := nil;
    Value := 'o';
  end;
  with LongOpts[12] do
  begin
    Name := 'prompt';
    Has_arg := Required_Argument;
    Flag := nil;
    Value := 'p';
  end;
  with LongOpts[13] do
  begin
    Name := 'quiet';
    Has_arg := No_Argument;
    Flag := nil;
    Value := 'q';
  end;
  with LongOpts[14] do
  begin
    Name := 'timeout';
    Has_arg := Required_Argument;
    Flag := nil;
    Value := 't';
  end;
  with LongOpts[15] do
  begin
    Name := '';
    Has_arg := No_Argument;
    Flag := nil;
    Value := #0;
  end;
  // set defaults
  ErrorCode := 0;
  ErrorMessage := '';
  AllowedChars := '';
  BeginningOfLine := false;
  DisallowChars := '';
  EmptyInputAllowed := false;
  GetMaxLength := false;
  Help := false;
  MaxLength := 0;
  MaskInput := false;
  MaskChar := '*';
  MinLength := 0;
  OvertypeMode := false;
  Prompt := '';
  Quiet := false;
  Timeout := 0;
  EnvVarName := '';
  MaxChars := 0;
  OptErr := false;  // no error outputs from wgetopts
  repeat
    Opt := GetLongOpts('a:bd:ehm::n:x:op:qt:', @LongOpts, I);
    case Opt of
      'a':
      begin
        if not IsValidCharList(OptArg) then
        begin
          ErrorCode := ERROR_INVALID_PARAMETER;
          ErrorMessage := '--allowedchars (-a) parameter has an invalid argument';
        end
        else
          AllowedChars := OptArg;
      end;
      'b':
        BeginningOfLine := true;
      'd':
      begin
        if not IsValidCharList(OptArg) then
        begin
          ErrorCode := ERROR_INVALID_PARAMETER;
          ErrorMessage := '--disallowchars (-d) parameter has an invalid argument';
        end
        else
          DisallowChars := OptArg;
      end;
      'e':
        EmptyInputAllowed := true;
      'h':
        Help := true;
      'm':
      begin
        MaskInput := true;
        if OptArg <> '' then
          MaskChar := OptArg[1];
      end;
      'n':
      begin
        if (OptArg = '') or (not StrToInt(OptArg, IntArg)) or
          (IntArg < 1) or (IntArg > MAX_ENVVAR_VALUE_LENGTH) then
        begin
          ErrorCode := ERROR_INVALID_PARAMETER;
          ErrorMessage :=
            '--minlength (-n) parameter requires a numeric argument in the range 1 to ' +
            IntToStr(MAX_ENVVAR_VALUE_LENGTH);
        end
        else
          MinLength := Word(IntArg);
      end;
      'x':
      begin
        if (OptArg = '') or (not StrToInt(OptArg, IntArg)) or
          (IntArg < 0) or (IntArg > MAX_ENVVAR_VALUE_LENGTH) then
        begin
          ErrorCode := ERROR_INVALID_PARAMETER;
          ErrorMessage := '--maxlength (-x) parameter requires a numeric argument in the range 0 to ' +
            IntToStr(MAX_ENVVAR_VALUE_LENGTH);
        end
        else
          MaxLength := Word(IntArg);
      end;
      'o':
        OvertypeMode := true;
      'p':
      begin
        if OptArg = '' then
        begin
          ErrorCode := ERROR_INVALID_PARAMETER;
          ErrorMessage := '--prompt (-p) parameter requires an argument';
        end
        else
          Prompt := OptArg;
      end;
      'q':
        Quiet := true;
      't':
      begin
        if (OptArg = '') or (not StrToInt(OptArg, IntArg)) or
          (IntArg < 1) or (IntArg > High(Word)) then
        begin
          ErrorCode := ERROR_INVALID_PARAMETER;
          ErrorMessage := '--timeout (-t) parameter requires a numeric argument in the range 1 to ' +
            IntToStr(High(Word));
        end
        else
          Timeout := Word(IntArg);
      end;
      #0:
      begin
        case LongOpts[I].Name of
          'debug':
          begin
            Debug := true;  // Currently does nothing
          end;
          'getmaxlength':
          begin
            GetMaxLength := true;
          end;
        end;
      end;
      '?':
      begin
        ErrorCode := ERROR_INVALID_PARAMETER;
        ErrorMessage := 'Invalid parameter detected; use --help (-h) for usage information';
      end;
    end;
  until Opt = EndOfOptions;
  if ErrorCode <> 0 then
    exit;
  MaxChars := (GetConsoleRows() * GetConsoleCols()) - Length(Prompt) - 1;
  if MaxLength = 0 then
  begin
    if MaxChars > MAX_ENVVAR_VALUE_LENGTH then
      MaxLength := MAX_ENVVAR_VALUE_LENGTH
    else
      MaxLength := MaxChars;
  end;
  if MaxLength > MaxChars then
  begin
    ErrorCode := ERROR_INSUFFICIENT_BUFFER;
    ErrorMessage := '--maxlength (-x) parameter cannot exceed ' +
      IntToStr(MaxChars) + ' characters';
    exit;
  end;
  if MinLength > 0 then
  begin
    if EmptyInputAllowed then
    begin
      ErrorCode := ERROR_INVALID_PARAMETER;
      ErrorMessage := 'You cannot specify both --minlength (-n) and --emptyinputallowed (-e)';
      exit;
    end;
    if (MaxLength > 0) and (MinLength > MaxLength) then
    begin
      ErrorCode := ERROR_INVALID_PARAMETER;
      ErrorMessage := '--minlength (-n) cannot exceed --maxlength (-x)';
      exit;
    end;
    if Timeout > 0 then
    begin
      ErrorCode := ERROR_INVALID_PARAMETER;
      ErrorMessage := 'You cannot specify both --minlength (-n) and --timeout (-t)';
      exit;
    end;
  end;
  if GetMaxLength then
    exit;
  EnvVarName := ParamStr(OptInd);
  if EnvVarName = '' then
  begin
    ErrorCode := ERROR_INVALID_PARAMETER;
    ErrorMessage := 'Environment variable name not specified';
    exit;
  end;
  if Pos('=', EnvVarName) > 0 then
  begin
    ErrorCode := ERROR_INVALID_PARAMETER;
    ErrorMessage := 'Environment variable name cannot contain = character';
    exit;
  end;
  if Length(EnvVarName) > MAX_ENVVAR_NAME_LENGTH then
  begin
    ErrorCode := ERROR_INSUFFICIENT_BUFFER;
    ErrorMessage := 'Environment variable name cannot exceed ' +
      IntToStr(MAX_ENVVAR_NAME_LENGTH) + ' characters';
    exit;
  end;
end;

// Checks for Windows Vista or later
function IsOSVersionNewEnough(): Boolean;
var
  OVI: OSVERSIONINFO;
begin
  result := false;
  OVI.dwOSVersionInfoSize := SizeOf(OSVERSIONINFO);
  if GetVersionEx(OVI) then
    result := (OVI.dwPlatformId = VER_PLATFORM_WIN32_NT) and (OVI.dwMajorVersion >= 6);
end;

var
  ProcessID, ParentProcessID: DWORD;
  CommandLine: TCommandLine;
  VarValue, NewValue: string;
  Editor: TLineEditor;
  Canceled, TimedOut: Boolean;

begin
  ExitCode := 0;

  if (ParamCount = 0) or (ParamStr(1) = '/?') then
  begin
    Usage();
    exit;
  end;

  CommandLine.Parse();

  if CommandLine.Help then
  begin
    Usage();
    exit;
  end;

  // Fail if OS is too old
  if not IsOSVersionNewEnough() then
  begin
    ExitCode := ERROR_OLD_WIN_VERSION;
    WriteLn(GetWindowsMessage(ExitCode, true));
    exit;
  end;

  if CommandLine.GetMaxLength then
  begin
    WriteLn(CommandLine.MaxLength);
    exit;
  end;

  ProcessID := GetCurrentProcessId();

  ExitCode := GetParentProcessID(ProcessID, ParentProcessID);
  if ExitCode <> 0 then
  begin
    if not CommandLine.Quiet then
      WriteLn(GetWindowsMessage(ExitCode, true));
    exit;
  end;

  // fail if bitness doesn't match
  if not CurrentProcessMatchesProcessBits(ParentProcessID) then
  begin
    ExitCode := ERROR_EXE_MACHINE_TYPE_MISMATCH;
    if not CommandLine.Quiet then
      WriteLn('Current and parent process must both be 32-bit or both 64-bit (',
        ExitCode, ')');
    exit;
  end;

  // Fail if running in PowerShell ISE
  if IsParentProcessName(ProcessID, 'powershell_ise.exe') then
  begin
    ExitCode := ERROR_INVALID_HANDLE;
    WriteLn(PROGRAM_NAME, ' does not work from the PowerShell ISE (',
      ExitCode, ')');
    exit;
  end;

  // fail if we got a command-line error
  ExitCode := CommandLine.ErrorCode;
  if ExitCode <> 0 then
  begin
    if not CommandLine.Quiet then
      WriteLn(CommandLine.ErrorMessage, ' (', CommandLine.ErrorCode, ')');
    exit;
  end;

  // fail if input mask requested and variable exists
  if CommandLine.MaskInput and EnvVarExists(CommandLine.EnvVarName) then
  begin
    ExitCode := ERROR_ALREADY_EXISTS;
    if not CommandLine.Quiet then
      WriteLn('Cannot use --maskinput (-m) parameter when environment variable exists (',
        ExitCode, ')');
    exit;
  end;

  VarValue := GetEnvVar(CommandLine.EnvVarName);

  // fail if environment variable value is too long
  if Length(VarValue) > MAX_ENVVAR_VALUE_LENGTH then
  begin
    ExitCode := ERROR_INSUFFICIENT_BUFFER;
    if not CommandLine.Quiet then
      WriteLn('Environment variable value cannot exceed ', MAX_ENVVAR_VALUE_LENGTH,
        ' characters (', ExitCode, ')');
    exit;
  end;

  // fail if environment variable value is longer than length limit
  if (CommandLine.MaxLength > 0) and (Length(VarValue) > CommandLine.MaxLength) then
  begin
    ExitCode := ERROR_INSUFFICIENT_BUFFER;
    if not CommandLine.Quiet then
      WriteLn('Environment variable value is longer than ',
        CommandLine.MaxLength, ' characters (', ExitCode, ')');
    exit;
  end;

  // Create line editor instance
  Editor := TLineEditor.Create();

  // Set line editor properties based on command-line parameters
  Editor.AllowedChars := CommandLine.AllowedChars;
  Editor.StartAtBOL := CommandLine.BeginningOfLine;
  Editor.DisallowChars := CommandLine.DisallowChars;
  Editor.MaxLength := CommandLine.MaxLength;
  Editor.MaskInput := CommandLine.MaskInput;
  if CommandLine.MaskInput then
    Editor.MaskChar := CommandLine.MaskChar;
  Editor.MinLength := CommandLine.MinLength;
  Editor.InsertMode := not CommandLine.OvertypeMode;
  Editor.Timeout := CommandLine.Timeout;

  if CommandLine.Prompt <> '' then
    Write(CommandLine.Prompt);

  // Start line editor
  NewValue := Editor.EditLine(VarValue);

  // Find out if canceled or timed out
  Canceled := Editor.Canceled;
  TimedOut := Editor.TimedOut;

  // Drop line editor from memory
  Editor.Destroy();

  if Canceled then
  begin
    ExitCode := ERROR_CANCELLED;
    exit;
  end;

  if TimedOut then
  begin
    ExitCode := WAIT_TIMEOUT;
    exit;
  end;

  if (NewValue = '') and (not CommandLine.EmptyInputAllowed) then
  begin
    ExitCode := ERROR_INVALID_DATA;
    if not CommandLine.Quiet then
      WriteLn('Environment variable value cannot be empty (', ExitCode, ')');
    exit;
  end;

  ExitCode := SetEnvVarInProcess(ParentProcessID, CommandLine.EnvVarName,
    NewValue);

  if (ExitCode <> 0) and (not CommandLine.Quiet) then
    WriteLn(GetWindowsMessage(ExitCode, true));
end.
