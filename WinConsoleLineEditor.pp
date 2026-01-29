{ Copyright (C) 2020-2026 by Bill Stewart (bstewart at iname.com)

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

{$MODE OBJFPC}
{$MODESWITCH UNICODESTRINGS}

unit WinConsoleLineEditor;

interface

const
  MAX_LINEEDITOR_LENGTH = High(Word);

type
  TLineEditor = class
  private
  var
    AllowedCharList: string;     // characters allowed for input
    DisallowedCharList: string;  // characters disallowed for input
    WordDelimCharList:  string;  // word delimiter characters
    IsCanceled: Boolean;         // true if Ctrl+C pressed
    IsTimedOut:  Boolean;        // true if timeout elapsed
    InputComplete: Boolean;      // true if Enter pressed and <= MinLen
    TimeoutSecs: Word;           // times out after this many seconds
    MaxLen: Word;                // maximum allowed # of characters
    MinLen: Word;                // minimum length # chars required
    CurrMaxLen: Word;            // grows as line length increases
    Line: string;                // line of text we're editing
    BackupLine: string;          // backup copy for Revert() method
    CurrPos: Integer;            // current cursor position in string
    function KeyPressedWithinTimeout(const Secs: Word): Boolean;
    procedure SetMaxLength(const MaxLength: Word);
    function GetMaxLength(): Word;
    function GetMinLength(): Word;
    procedure SetMinLength(const MinLength: Word);
    procedure SetTimeout(const Seconds: Word);
    function GetTimeout(): Word;
    function StringToCharList(const S: string): string;
    procedure SetWordDelims(const NewDelimiters: string);
    procedure SetAllowedChars(const AllowedChars: string);
    function GetAllowedChars(): string;
    procedure SetDisallowedChars(const DisallowedChars: string);
    function GetDisallowedChars(): string;
    procedure EditCursorLeft(const NumChars: Integer);
    procedure EditCursorRight(const NumChars: Integer);
    procedure BegLine();
    procedure EndLine();
    procedure ShowLine();
    procedure DeleteLine();
    procedure InsertStr(S: string);
    procedure Paste();
    procedure DeleteChar();
    procedure Backspace();
    procedure DeleteToBOL();
    procedure DeleteToEOL();
    procedure WordLeft();
    procedure WordRight();
    procedure Cancel();
    procedure ToggleInsert();
    procedure Enter();
    procedure Revert();
  public
  var
    InsertMode: Boolean;
    MaskInput: Boolean;
    MaskChar: Char;
    StartAtBOL: Boolean;
    property Canceled: Boolean read IsCanceled;
    property TimedOut: Boolean read IsTimedOut;
    property MaxLength: Word read GetMaxLength write SetMaxLength;
    property MinLength: Word read GetMinLength write SetMinLength;
    property Timeout: Word read GetTimeout write SetTimeout;
    property AllowedChars: string read GetAllowedChars write SetAllowedChars;
    property DisallowChars: string read GetDisallowedChars write SetDisallowedChars;
    property WordDelimiters: string write SetWordDelims;
    constructor Create();
    destructor Destroy(); override;
    function EditLine(const StringToEdit: string): string;
  end;

implementation

// WinKeyboard and WinGetKey - https://github.com/Bill-Stewart/WinGetKey
uses
  windows,
  WinConsole,
  WinKeyboard,
  WinGetKey;

function GetClipboardText(): string;
var
  Data: HANDLE;
  I, P: Integer;
begin
  result := '';
  if OpenClipboard(0) then  // HWND hWndNewOwner
  begin
    Data := GetClipboardData(CF_UNICODETEXT);  // UINT uFormat
    try
      if Data <> 0 then
        result := PChar(GlobalLock(Data));  // HGLOBAL hMem
    finally
      if Data <> 0 then
        GlobalUnlock(Data);  // HGLOBAL hMem
    end;
    CloseClipboard();
  end;
  if result <> '' then
  begin
    // Replace all control characters with spaces
    for I := 0 to 31 do
    begin
      P := Pos(Char(I), result);
      while P > 0 do
      begin
        result[P] := ' ';
        P := Pos(Char(I), result);
      end;
    end;
  end;
end;

function StringOfChar(const C: Char; const Len: Integer): string;
begin
  SetLength(result, Len);
  if Len > 0 then
    FillWord(Pointer(result)^, Length(result), Word(C));
end;

// Returns true if key pressed within the specified number of seconds, or
// false otherwise (timer is not high precision)
function TLineEditor.KeyPressedWithinTimeout(const Secs: Word): Boolean;
var
  Freq, Start, Interval, Step: Int64;
begin
  result := false;
  if QueryPerformanceFrequency(Freq) then  // LARGE_INTEGER *lpFrequency
  begin
    Interval := Secs * Freq;
    QueryPerformanceCounter(Start);  // LARGE_INTEGER *lpPerformanceCount
    while (not KeyPressed()) and (QueryPerformanceCounter(Step)) and (Step - Start < Interval) do
      Sleep(1);
    result := KeyPressed();
  end;
end;

function TLineEditor.StringToCharList(const S: string): string;
var
  I: Integer;
begin
  result := '';
  for I := 1 to Length(S) do
    if Pos(S[I], result) = 0 then
      result := result + S[I];
end;

procedure TLineEditor.SetWordDelims(const NewDelimiters: string);
begin
  WordDelimCharList := StringToCharList(NewDelimiters);
end;

procedure TLineEditor.SetAllowedChars(const AllowedChars: string);
begin
  AllowedCharList := StringToCharList(AllowedChars);
end;

function TLineEditor.GetAllowedChars(): string;
begin
  result := AllowedCharList;
end;

procedure TLineEditor.SetDisallowedChars(const DisallowedChars: string);
begin
  DisallowedCharList := StringToCharList(DisallowedChars);
end;

function TLineEditor.GetDisallowedChars(): string;
begin
  result := DisallowedCharList;
end;

function TLineEditor.GetMaxLength(): Word;
begin
  result := MaxLen;
end;

procedure TLineEditor.SetMaxLength(const MaxLength: Word);
begin
  if MaxLength >= 1 then
    MaxLen := MaxLength;
end;

function TLineEditor.GetMinLength(): Word;
begin
  result := MinLen;
end;

procedure TLineEditor.SetMinLength(const MinLength: Word);
begin
  MinLen := MinLength;
end;

procedure TLineEditor.SetTimeout(const Seconds: Word);
begin
  if Seconds >= 1 then
    TimeoutSecs := Seconds;
end;

function TLineEditor.GetTimeout(): Word;
begin
  result := TimeoutSecs;
end;

constructor TLineEditor.Create();
begin
  MaskInput := false;
  InsertMode := true;
  InputComplete := false;
  MaskChar := '*';
  MaxLen := MAX_LINEEDITOR_LENGTH;
  MinLen := 0;
  Timeout := 0;
  StartAtBOL := false;
  AllowedCharList := '';
  DisallowedCharList := '';
  WordDelimCharList := StringToCharList(#9 + ' ;/\');
end;

destructor TLineEditor.Destroy();
begin
end;

procedure TLineEditor.EditCursorLeft(const NumChars: Integer);
begin
  if not MaskInput then
  begin
    if (Line <> '') and (CurrPos > 1) then
    begin
      MoveCursorLeft(NumChars);
      Dec(CurrPos, NumChars);
    end;
  end;
end;

procedure TLineEditor.EditCursorRight(const NumChars: Integer);
begin
  if not MaskInput then
  begin
    if (Line <> '') and (CurrPos < (Length(Line) + 1)) then
    begin
      MoveCursorRight(NumChars);
      Inc(CurrPos, NumChars);
    end;
  end;
end;

procedure TLineEditor.BegLine();
begin
  if not MaskInput then
  begin
    if CurrPos > 1 then
    begin
      MoveCursorLeft(CurrPos - 1);
      CurrPos := 1;
    end;
  end;
end;

procedure TLineEditor.EndLine();
begin
  if not MaskInput then
  begin
    if CurrPos < Length(Line) + 1 then
    begin
      EditCursorRight(Length(Line) - CurrPos + 1);
      CurrPos := Length(Line) + 1;
    end;
  end;
end;

procedure TLineEditor.ShowLine();
var
  Tail, S: string;
begin
  Tail := StringOfChar(' ', CurrMaxLen - Length(Line));
  if MaskInput then
    S := StringOfChar(MaskChar, Length(Line)) + Tail
  else
    S := Line + Tail;
  if CurrPos > 1 then
    Delete(S, 1, CurrPos - 1);
  OutStr(S);
  MoveCursorLeft(Length(S));
end;

procedure TLineEditor.DeleteLine();
begin
  if Line <> '' then
  begin
    if CurrPos > 1 then
    begin
      MoveCursorLeft(CurrPos - 1);
      CurrPos := 1;
    end;
    Line := '';
    ShowLine();
  end;
end;

procedure TLineEditor.InsertStr(S: string);
begin
  if (InsertMode and (Length(Line) < MaxLen)) or (not InsertMode and (CurrPos <= MaxLen)) then
  begin
    if InsertMode then
    begin
      Insert(S, Line, CurrPos);
    end
    else
    begin
      if (Line <> '') and (CurrPos <= Length(Line)) then
        Delete(Line, CurrPos, 1);
      Insert(S, Line, CurrPos);
    end;
    if MaskInput then
      OutStr(StringOfChar(MaskChar, Length(S)))
    else
      OutStr(S);
    Inc(CurrPos, Length(S));
    if Length(Line) > CurrMaxLen then  // grow CurrMaxLen as needed
      CurrMaxLen := Length(Line);
    ShowLine();
  end;
end;

procedure TLineEditor.Paste();
var
  S: string;
  I: Integer;
begin
  S := GetClipboardText();
  if S = '' then
    exit;
  // Insert one character at a time to respect input validity and length
  // (i.e., mimic console or terminal paste)
  for I := 1 to Length(S) do
  begin
    if (DisallowedCharList = '') or (Pos(S[I], DisallowedCharList) = 0) then
    begin
      if (AllowedCharList = '') or (Pos(S[I], AllowedCharList) > 0) then
      begin
        if CurrPos - 1 < MaxLen then
          InsertStr(S[I]);
      end;
    end;
  end;
end;

procedure TLineEditor.DeleteChar();
begin
  if not MaskInput then
  begin
    if (Line <> '') and (CurrPos <= Length(Line)) then
    begin
      Delete(Line, CurrPos, 1);
      ShowLine();
    end;
  end;
end;

procedure TLineEditor.Backspace();
begin
  if not MaskInput then
  begin
    if (Line <> '') and (CurrPos > 1) and (CurrPos <= Length(Line) + 1) then
    begin
      EditCursorLeft(1);
      DeleteChar();
    end;
  end
  else
  begin
    if (Line <> '') and (CurrPos > 1) then
    begin
      MoveCursorLeft(1);
      Dec(CurrPos, 1);
      Delete(Line, CurrPos, 1);
      ShowLine();
    end;
  end;
end;

procedure TLineEditor.DeleteToBOL();
begin
  if not MaskInput then
  begin
    if CurrPos > 1 then
    begin
      Delete(Line, 1, CurrPos - 1);
      BegLine();
      ShowLine();
    end;
  end;
end;

procedure TLineEditor.DeleteToEOL();
begin
  if not MaskInput then
  begin
    if CurrPos <= Length(Line) then
    begin
      Delete(Line, CurrPos, Length(Line) - CurrPos + 1);
      EndLine();
      ShowLine();
    end;
  end;
end;

procedure TLineEditor.WordLeft();
var
  I: Integer;
begin
  if not MaskInput then
  begin
    I := CurrPos;
    if I > 1 then
    begin
      repeat
        Dec(I);
      until (I = 1) or ((Pos(Line[I - 1], WordDelimCharList) > 0) and (Pos(Line[I], WordDelimCharList) = 0));
      EditCursorLeft(CurrPos - I);
    end;
  end;
end;

procedure TLineEditor.WordRight();
var
  I: Integer;
begin
  if not MaskInput then
  begin
    I := CurrPos;
    if I < Length(Line) + 1 then
    begin
      repeat
        Inc(I);
      until (I = Length(Line) + 1) or ((Pos(Line[I - 1], WordDelimCharList) > 0) and (Pos(Line[I], WordDelimCharList) = 0));
      EditCursorRight(I - CurrPos);
    end;
  end;
end;

procedure TLineEditor.Cancel();
begin
  IsCanceled := true;
  OutStr('^C');
  Inc(CurrPos, 2);
  EndLine();
end;

procedure TLineEditor.ToggleInsert();
begin
  if not MaskInput then
    InsertMode := not InsertMode;
end;

procedure TLineEditor.Enter();
begin
  InputComplete := Length(Line) >= MinLen;
  if InputComplete then
    EndLine();
end;

procedure TLineEditor.Revert();
begin
  if not MaskInput then
  begin
    DeleteLine();
    Line := BackupLine;
    ShowLine();
    if not StartAtBOL then
      EndLine();
  end;
end;

function TLineEditor.EditLine(const StringToEdit: string): string;
var
  Key: string;
  ControlKey: Boolean;
begin
  // Need to disable ENABLE_VIRTUAL_TERMINAL_PROCESSING flag; otherwise,
  // writing past the edge of the screen won't scroll in WT
  SetConsoleVTMode(false);
  IsCanceled := false;
  IsTimedOut := false;
  CurrPos := 1;
  if not MaskInput then
  begin
    Line := StringToEdit;
    if Length(Line) > MaxLen then
      SetLength(Line, MaxLen);
    CurrMaxLen := Length(Line);
    BackupLine := Line;
    ShowLine();
    if not StartAtBOL then
      EndLine();
  end
  else
  begin
    Line := '';
    CurrMaxLen := 0;
  end;
  if (MinLength = 0) and (TimeoutSecs > 0) then
    IsTimedOut := not KeyPressedWithinTimeout(TimeoutSecs);
  if not IsTimedOut then
  repeat
    Key := GetKey(ControlKey);
    if ControlKey then
    begin
      case Key of
        'Insert': ToggleInsert();
        'Left': EditCursorLeft(1);
        'Right': EditCursorRight(1);
        'Ctrl+A','Home': BegLine();
        'Ctrl+C': Cancel();
        'Ctrl+E', 'End': EndLine();
        'Delete': DeleteChar();
        'Ctrl+Home': DeleteToBOL();
        'Ctrl+End': DeleteToEOL();
        'Ctrl+Left': WordLeft();
        'Ctrl+Right': WordRight();
        'Enter': Enter();
        'Ctrl+U','Ctrl+Z': Revert();
        'Esc': DeleteLine();
        'Backspace','Ctrl+Backspace': Backspace();
        'Ctrl+V','Shift+Insert': Paste();
      end;
    end
    else
    begin
      if (DisallowedCharList = '') or (Pos(Key, DisallowedCharList) = 0) then
      begin
        if (AllowedCharList = '') or (Pos(Key, AllowedCharList) > 0) then
          InsertStr(Key);
      end;
    end;
  until IsCanceled or InputComplete;
  if IsCanceled then
    result := ''
  else
    result := Line;
  SetConsoleVTMode(true);
  OutStr(#13 + #10);
end;

initialization

finalization

end.
