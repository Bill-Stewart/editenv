{ editenv - Windows console program for interactively editing the value of an
  environment variable

  Copyright (C) 2020-2021 by Bill Stewart (bstewart at iname.com)

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

program editenv;

{$MODE OBJFPC}
{$H+}
{$APPTYPE CONSOLE}
{$R *.res}

uses
  getopts,
  Windows,
  wsWinEnvVar,
  wsWinLineEditor,
  wsWinMessage,
  wsWinProcess,
  wsWinString;

type
  TCommandLine = object
    ErrorCode:         Word;            // <> 0 if error parsing command line
    ErrorMessage:      UnicodeString;   // error message
    AllowedChars:      string;          // --allowedchars
    BeginningOfLine:   Boolean;         // --beginningofline
    DisallowChars:     string;          // --disallowchars and --disallowquotes
    EmptyInputAllowed: Boolean;         // --emptyinputallowed
    Help:              Boolean;         // --help
    MaxLength:         Word;            // --maxlength
    MaskInput:         Boolean;         // --maskinput
    MaskChar:          Char;            // --maskinput character
    MinLength:         Word;            // --minlength
    OvertypeMode:      Boolean;         // --overtypemode
    Prompt:            UnicodeString;   // --prompt
    Quiet:             Boolean;         // --quiet
    Timeout:           Word;            // --timeout
    EnvVarName:        UnicodeString;   // name of env var to edit
    function LongIntToUnicodeString(const N: LongInt): UnicodeString;
    function StringToLongInt(const S: string; var N: LongInt): Boolean;
    procedure Parse();
  end;

var
  ProcessID: DWORD;
  CommandLine: TCommandLine;
  VarValue: UnicodeString;
  NewValue: string;
  Editor: TLineEditor;
  Canceled, TimedOut: Boolean;

procedure Usage();
begin
  WriteLn('editenv - Copyright (C) 2020-2021 by Bill Stewart (bstewart at iname.com)');
  WriteLn('This is free software and comes with ABSOLUTELY NO WARRANTY.');
  WriteLn();
  WriteLn('SYNOPSIS');
  WriteLn();
  WriteLn('editenv is a Windows console program that lets you interactively edit the value');
  WriteLn('of an environment variable.');
  WriteLn();
  WriteLn('USAGE');
  WriteLn();
  WriteLn('editenv [parameter [...]] variablename');
  WriteLn();
  WriteLn('Parameter           Abbrev. Description');
  WriteLn('------------------- ------- -------------------------------------------');
  WriteLn('--allowedchars=...  -a ...  Only allows input of specified characters');
  WriteLn('--beginningofline   -b      Starts cursor at beginning of line');
  WriteLn('--disallowchars=... -D ...  Disallows input of specified characters');
  WriteLn('--disallowquotes    -d      Disallows input of " character');
  WriteLn('--emptyinputallowed -e      Empty input is allowed to remove variable');
  WriteLn('--help              -h      Displays usage information');
  WriteLn('--maskinput[=x]     -m x    Masks input using character x (default=*)');
  WriteLn('--minlength=n       -n n    Input must be at least n character(s)');
  WriteLn('--maxlength=n       -x n    Input cannot be longer than n character(s)');
  WriteLn('--overtypemode      -o      Starts line editor in overtype mode');
  WriteLn('--prompt=...        -p ...  Specifies an input prompt');
  WriteLn('--quiet             -q      Suppresses error messages');
  WriteLn('--timeout=n         -t n    Automatically enter input after n second(s)');
  WriteLn();
  WriteLn('Parameter names are case-sensitive.');
  WriteLn();
  WriteLn('LINE EDITOR');
  WriteLn();
  WriteLn('The line editor supports the following keystroke commands:');
  WriteLn();
  WriteLn('Key                   Action');
  WriteLn('--------------------- -----------------------------------------------');
  WriteLn('Left, Right           Moves cursor left or right');
  WriteLn('Home or Ctrl+A        Moves cursor to beginning of line');
  WriteLn('End or Ctrl+E         Moves cursor to end of line');
  WriteLn('Ctrl+Left, Ctrl+Right Moves cursor left or right one word');
  WriteLn('Insert                Toggle between insert and overtype mode');
  WriteLn('Delete                Deletes the character under the cursor');
  WriteLn('Backspace or Ctrl+H   Deletes the character to the left of the cursor');
  WriteLn('Ctrl+Home             Deletes to the beginning of the line');
  WriteLn('Ctrl+End              Deletes to the end of the line');
  WriteLn('Esc or Ctrl+[         Deletes the entire line');
  WriteLn('Ctrl+U or Ctrl+Z      Reverts line to original value');
  WriteLn('Ctrl+C                Cancel input');
  WriteLn('Enter or Ctrl+M       Enter input');
  WriteLn();
  WriteLn('EXIT CODES');
  WriteLn();
  WriteLn('Description                                                Exit Code');
  WriteLn('---------------------------------------------------------- ---------');
  WriteLn('No error                                                   ', ERROR_SUCCESS);
  WriteLn('Empty input and --emptyinputallowed (-e) not specified     ', ERROR_INVALID_DATA);
  WriteLn('Command line contains an error                             ', ERROR_INVALID_PARAMETER);
  WriteLn('Environment variable name or value are too long            ', ERROR_INSUFFICIENT_BUFFER);
  WriteLn('Cannot use --maskinput (-m) parameter when variable exists ', ERROR_ALREADY_EXISTS);
  WriteLn('Current and parent process must both be 32-bit or 64-bit   ', ERROR_EXE_MACHINE_TYPE_MISMATCH);
  WriteLn('--timeout (-t) period elapsed                              ', WAIT_TIMEOUT);
  WriteLn('Ctrl+C pressed to cancel input                             ', ERROR_CANCELLED);
  WriteLn();
  WriteLn('* In cmd.exe, you can check the exit code using the %ERRORLEVEL% variable or');
  WriteLn('  the if errorlevel command.');
  WriteLn('* In PowerShell, you can check the exit code using the $LASTEXITCODE variable.');
  WriteLn();
  WriteLn('NOTES/LIMITATIONS');
  WriteLn();
  WriteLn('* The environment variable''s name cannot contain the = character');
  WriteLn('* The environment variable''s name is limited to ', MAX_ENVVAR_NAME_LENGTH, ' characters');
  WriteLn('* The environment variable''s value is limited to ', MAX_ENVVAR_VALUE_LENGTH, ' characters');
  WriteLn('* The --timeout (-t) parameter does not use a high-precision timer');
  WriteLn('* The --maskinput (-m) parameter is not encrypted or secure');
  WriteLn('* There is no visual indication of insert vs. overtype mode');
  WriteLn('* editenv does not work from the PowerShell ISE');
end;

// Returns N as a string
function TCommandLine.LongIntToUnicodeString(const N: LongInt): UnicodeString;
begin
  Str(N, result);
end;

// Returns true if S can be converted to longint (output in N), or false
// if S cannot be converted to longint
function TCommandLine.StringToLongInt(const S: string; var N: LongInt): Boolean;
var
  E: Word;
begin
  Val(S, N, E);
  result := E = 0;
end;

// Parse the command line
procedure TCommandLine.Parse();
var
  LongOpts: array[1..15] of TOption;
  Opt: Char;
  I, IntArg: LongInt;
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
    Name := 'disallowchars';
    Has_arg := Required_Argument;
    Flag := nil;
    Value := 'D';
  end;
  with LongOpts[4] do
  begin
    Name := 'disallowquotes';
    Has_arg := No_Argument;
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
    Name := 'help';
    Has_arg := No_Argument;
    Flag := nil;
    Value := 'h';
  end;
  with LongOpts[7] do
  begin
    // --limitlength (-l) deprecated in favor of --maxlength (-x)
    Name := 'limitlength';
    Has_arg := Required_Argument;
    Flag := nil;
    Value := 'l';
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
  OptErr := false;  // no error outputs from getopts
  repeat
    Opt := GetLongOpts('a:bD:dehm::n:x:l:op:qt:', @LongOpts, I);
    case Opt of
      'a':
      begin
        if OptArg = '' then
        begin
          ErrorCode := ERROR_INVALID_PARAMETER;
          ErrorMessage := '--allowedchars (-a) parameter requires an argument';
        end
        else
          AllowedChars := OptArg;
      end;
      'b':
        BeginningOfLine := true;
      'D':
      begin
        if OptArg = '' then
        begin
          ErrorCode := ERROR_INVALID_PARAMETER;
          ErrorMessage := '--disallowchars (-D) parameter requires an argument';
        end
        else
          DisallowChars := OptArg;
      end;
      'd':
      begin
        if DisallowChars <> '' then
          DisallowChars := DisallowChars + '"'
        else
          DisallowChars := '"';
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
        if (OptArg = '') or (not StringToLongInt(OptArg, IntArg)) or (IntArg < 1) or (IntArg > MAX_ENVVAR_VALUE_LENGTH) then
        begin
          ErrorCode := ERROR_INVALID_PARAMETER;
          ErrorMessage := '--minlength (-n) parameter requires a numeric argument in the range 1 to ' +
            LongIntToUnicodeString(MAX_ENVVAR_VALUE_LENGTH);
        end
        else
          MinLength := Word(IntArg);
      end;
      'x','l':  // 'l' is deprecated
      begin
        if (OptArg = '') or (not StringToLongInt(OptArg, IntArg)) or (IntArg < 0) or (IntArg > MAX_ENVVAR_VALUE_LENGTH) then
        begin
          ErrorCode := ERROR_INVALID_PARAMETER;
          ErrorMessage := '--maxlength (-x) parameter requires a numeric argument in the range 0 to ' +
            LongIntToUnicodeString(MAX_ENVVAR_VALUE_LENGTH);
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
          Prompt := StringToUnicodeString(OptArg);
      end;
      'q':
        Quiet := true;
      't':
      begin
        if (OptArg = '') or (not StringToLongInt(OptArg, IntArg)) or (IntArg < 1) or (IntArg > High(Word)) then
        begin
          ErrorCode := ERROR_INVALID_PARAMETER;
          ErrorMessage := '--timeout (-t) parameter requires a numeric argument in the range 1 to ' +
            LongIntToUnicodeString(High(Word));
        end
        else
          Timeout := Word(IntArg);
      end;
      '?':
      begin
        ErrorCode := ERROR_INVALID_PARAMETER;
        ErrorMessage := 'Invalid parameter detected; use --help (-h) for usage information';
      end;
    end; //case
  until Opt = EndOfOptions;
  if ErrorCode <> 0 then
    exit();
  EnvVarName := StringToUnicodeString(ParamStr(OptInd));
  if EnvVarName = '' then
  begin
    ErrorCode := ERROR_INVALID_PARAMETER;
    ErrorMessage := 'Environment variable name not specified';
    exit();
  end;
  if Pos('=', EnvVarName) > 0 then
  begin
    ErrorCode := ERROR_INVALID_PARAMETER;
    ErrorMessage := 'Environment variable name cannot contain = character';
    exit();
  end;
  if MinLength > 0 then
  begin
    if EmptyInputAllowed then
    begin
      ErrorCode := ERROR_INVALID_PARAMETER;
      ErrorMessage := 'You cannot specify both --minlength (-n) and --emptyinputallowed (-e)';
    end;
    if (MaxLength > 0) and (MinLength > MaxLength) then
    begin
      ErrorCode := ERROR_INVALID_PARAMETER;
      ErrorMessage := '--minlength (-n) cannot exceed --maxlength (-x)';
      exit();
    end;
    if Timeout > 0 then
    begin
      ErrorCode := ERROR_INVALID_PARAMETER;
      ErrorMessage := 'You cannot specify both --minlength (-n) and --timeout (-t)';
      exit();
    end;
  end;
  if Length(EnvVarName) > MAX_ENVVAR_NAME_LENGTH then
  begin
    ErrorCode := ERROR_INSUFFICIENT_BUFFER;
    ErrorMessage := 'Environment variable name cannot exceed ' + LongIntToUnicodeString(MAX_ENVVAR_NAME_LENGTH) + ' characters';
    exit();
  end;
end;

function IsOSVersionNewEnough(): Boolean;
var
  OVI: OSVERSIONINFO;
begin
  result := false;
  OVI.dwOSVersionInfoSize := SizeOf(OSVERSIONINFO);
  if GetVersionEx(OVI) then
    result := (OVI.dwPlatformId = VER_PLATFORM_WIN32_NT) and (OVI.dwMajorVersion >= 5);
end;

begin
  if (ParamCount = 0) or (ParamStr(1) = '/?') then
  begin
    Usage();
    ExitCode := 0;
    exit();
  end;

  // Fail if OS is too old
  if not IsOSVersionNewEnough() then
  begin
    ExitCode := ERROR_OLD_WIN_VERSION;
    WriteLn(GetWindowsMessage(ExitCode, true));
    exit();
  end;

  CommandLine.Parse();

  if CommandLine.Help then
  begin
    Usage();
    ExitCode := 0;
    exit();
  end;

  ExitCode := GetParentProcessID(ProcessID);
  // fail if we can't get parent process ID
  if ExitCode <> 0 then
  begin
    if not CommandLine.Quiet then
      WriteLn(GetWindowsMessage(ExitCode, true));
    exit();
  end;

  // fail if bitness doesn't match
  if not CurrentProcessMatchesProcessBits(ProcessID) then
  begin
    ExitCode := ERROR_EXE_MACHINE_TYPE_MISMATCH;
    if not CommandLine.Quiet then
      WriteLn('Current and parent process must both be 32-bit or both 64-bit (', ExitCode, ')');
    exit();
  end;

  // fail if we got a command-line error
  ExitCode := CommandLine.ErrorCode;
  if ExitCode <> 0 then
  begin
    if not CommandLine.Quiet then
      WriteLn(CommandLine.ErrorMessage, ' (', CommandLine.ErrorCode, ')');
    exit();
  end;

  // fail if input mask requested and variable exists
  if CommandLine.MaskInput and EnvVarExists(CommandLine.EnvVarName) then
  begin
    ExitCode := ERROR_ALREADY_EXISTS;
    if not CommandLine.Quiet then
      WriteLn('Cannot use --maskinput (-m) parameter when environment variable exists (', ExitCode, ')');
    exit();
  end;

  // fail if environment variable value is too long
  VarValue := GetEnvVar(CommandLine.EnvVarName);
  if Length(VarValue) > MAX_ENVVAR_VALUE_LENGTH then
  begin
    ExitCode := ERROR_INSUFFICIENT_BUFFER;
    if not CommandLine.Quiet then
      WriteLn('Environment variable value cannot exceed ', MAX_ENVVAR_VALUE_LENGTH, ' characters (', ExitCode, ')');
    exit();
  end;

  // fail if environment variable value is longer than length limit
  if (CommandLine.MaxLength > 0) and (Length(VarValue) > CommandLine.MaxLength) then
  begin
    ExitCode := ERROR_INSUFFICIENT_BUFFER;
    if not CommandLine.Quiet then
      WriteLn('Environment variable value is longer than ', CommandLine.MaxLength, ' characters (', ExitCode, ')');
    exit();
  end;

  if CommandLine.Prompt <> '' then
    Write(CommandLine.Prompt);

  // Create instance
  Editor := TLineEditor.Create();

  // Set properties based on command-line parameters
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

  // Start the editor
  NewValue := Editor.EditLine(UnicodeStringToString(VarValue));

  // Find out if canceled or timed out
  Canceled := Editor.Canceled;
  TimedOut := Editor.TimedOut;

  // Destroy instance
  Editor.Destroy();

  if Canceled then
  begin
    ExitCode := ERROR_CANCELLED;
    exit();
  end;

  if TimedOut then
  begin
    ExitCode := WAIT_TIMEOUT;
    exit();
  end;

  if (NewValue = '') and (not CommandLine.EmptyInputAllowed) then
  begin
    ExitCode := ERROR_INVALID_DATA;
    if not CommandLine.Quiet then
      WriteLn('Environment variable value cannot be empty (', ExitCode, ')');
    exit();
  end;

  ExitCode := SetEnvVarInProcess(ProcessID, CommandLine.EnvVarName,
    StringToUnicodeString(NewValue));

  if (ExitCode <> 0) and (not CommandLine.Quiet) then
    WriteLn(GetWindowsMessage(ExitCode, true));
end.
