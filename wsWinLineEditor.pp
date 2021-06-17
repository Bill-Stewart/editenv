{ Copyright (C) 2020-2021 by Bill Stewart (bstewart at iname.com)

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
{$H+}

unit wsWinLineEditor;

interface

uses
  keyboard,
  Windows,
  wsWinConsole;

const
  MAX_LINEEDITOR_LENGTH = High(Word);

type
  TLineEditor = class
  private
    type
    TCharSet = set of Char;
  var
    AllowedCharSet:    TCharSet;  // characters allowed for input
    DisallowedCharSet: TCharSet;  // characters disallowed for input
    WordDelims:        TCharSet;  // word delimiter characters
    IsCanceled:        Boolean;   // true if Ctrl+C pressed
    IsTimedOut:        Boolean;   // true if timeout elapsed
    InputComplete:     Boolean;   // true if Enter pressed and <= MinLen
    TimeoutSecs:       Word;      // times out after this many seconds
    MaxLen:            Word;      // maximum allowed # of characters
    MinLen:            Word;      // minimum length # chars required
    CurrMaxLen:        Word;      // grows as line length increases
    Line:              string;    // line of text we're editing
    BackupLine:        string;    // backup copy for Revert() method
    CurrPos:           LongInt;   // current cursor position in string
    function KeyPressedWithinTimeout(const Secs: Word): Boolean;
    procedure SetMaxLength(const MaxLength: Word);
    function GetMaxLength(): Word;
    function GetMinLength(): Word;
    procedure SetMinLength(const MinLength: Word);
    procedure SetTimeout(const Seconds: Word);
    function GetTimeout(): Word;
    function StringToCharSet(const Text: string): TCharSet;
    procedure SetWordDelims(const NewDelimiters: string);
    procedure SetAllowedChars(const AllowedChars: string);
    procedure SetDisallowedChars(const DisallowedChars: string);
    procedure EditCursorLeft(const NumChars: LongInt);
    procedure EditCursorRight(const NumChars: LongInt);
    procedure BegLine();
    procedure EndLine();
    procedure ShowLine();
    procedure DeleteLine();
    procedure InsertChar(Ch: Char);
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
    MaskInput:  Boolean;
    MaskChar:   Char;
    StartAtBOL: Boolean;
    property Canceled: Boolean read IsCanceled;
    property TimedOut: Boolean read IsTimedOut;
    property MaxLength: Word read GetMaxLength write SetMaxLength;
    property MinLength: Word read GetMinLength write SetMinLength;
    property Timeout: Word read GetTimeout write SetTimeout;
    property AllowedChars: string write SetAllowedChars;
    property DisallowChars: string write SetDisallowedChars;
    property WordDelimiters: string write SetWordDelims;
    constructor Create();
    destructor Destroy(); override;
    function EditLine(const Text: string): string;
  end;

implementation

// Returns true if key pressed within the specified number of seconds, or
// false otherwise (timer is not high precision)
function TLineEditor.KeyPressedWithinTimeout(const Secs: Word): Boolean;
var
  Freq, Start, Interval, Step: Int64;
begin
  result := false;
  if QueryPerformanceFrequency(Freq) then
  begin
    Interval := Secs * Freq;
    QueryPerformanceCounter(Start);
    while (not KeyPressed()) and (QueryPerformanceCounter(Step)) and (Step - Start < Interval) do
      Sleep(1);
    result := KeyPressed();
  end;
end;

// Returns a set containing the characters in the specified string
function TLineEditor.StringToCharSet(const Text: string): TCharSet;
var
  I: LongInt;
begin
  result := [];
  for I := 1 to Length(Text) do
    Include(result, Text[I]);
end;

procedure TLineEditor.SetWordDelims(const NewDelimiters: string);
begin
  WordDelims := StringToCharSet(NewDelimiters);
end;

procedure TLineEditor.SetAllowedChars(const AllowedChars: string);
begin
  AllowedCharSet := StringToCharSet(AllowedChars);
end;

procedure TLineEditor.SetDisallowedChars(const DisallowedChars: string);
begin
  DisallowedCharSet := StringToCharSet(DisallowedChars);
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
  InitKeyboard();
  DisableBreak();  // ignore Ctrl+C/Ctrl+Break and treat Ctrl+C as input
  MaskInput := false;
  InsertMode := true;
  InputComplete := false;
  MaskChar := '*';
  MaxLen := MAX_LINEEDITOR_LENGTH;
  MinLen := 0;
  Timeout := 0;
  StartAtBOL := false;
  AllowedCharSet := [];
  DisallowedCharSet := [];
  WordDelims := StringToCharSet(#9 + ' ;/\');
end;

destructor TLineEditor.Destroy();
begin
  DoneKeyboard();
end;

procedure TLineEditor.EditCursorLeft(const NumChars: LongInt);
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

procedure TLineEditor.EditCursorRight(const NumChars: LongInt);
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
  Part: string;
begin
  SetLength(Part, CurrMaxLen);
  FillChar(Pointer(Part)^, CurrMaxLen, ' ');
  if MaskInput then
    FillChar(Pointer(Part)^, Length(Line), MaskChar)
  else
    Move(Pointer(Line)^, Pointer(Part)^, Length(Line));
  if CurrPos > 1 then
    Delete(Part, 1, CurrPos - 1);
  Write(Part);
  MoveCursorLeft(Length(Part));
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

procedure TLineEditor.InsertChar(Ch: Char);
begin
  if (InsertMode and (Length(Line) < MaxLen)) or (not InsertMode and (CurrPos <= MaxLen)) then
  begin
    if InsertMode then
    begin
      Insert(Ch, Line, CurrPos);
    end
    else
    begin
      if (Line <> '') and (CurrPos <= Length(Line)) then
        Delete(Line, CurrPos, 1);
      Insert(Ch, Line, CurrPos);
    end;
    if MaskInput then
      Write(MaskChar)
    else
      Write(Ch);
    Inc(CurrPos);
    if Length(Line) > CurrMaxLen then  // grow CurrMaxLen as needed
      CurrMaxLen := Length(Line);
    ShowLine();
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
  I: LongInt;
begin
  if not MaskInput then
  begin
    I := CurrPos;
    if I > 1 then
    begin
      repeat
        Dec(I);
      until (I = 1) or ((Line[I - 1] in WordDelims) and (not (Line[I] in WordDelims)));
      EditCursorLeft(CurrPos - I);
    end;
  end;
end;

procedure TLineEditor.WordRight();
var
  I: LongInt;
begin
  if not MaskInput then
  begin
    I := CurrPos;
    if I < Length(Line) + 1 then
    begin
      repeat
        Inc(I);
      until (I = Length(Line) + 1) or ((Line[I - 1] in WordDelims) and (not (Line[I] in WordDelims)));
      EditCursorRight(I - CurrPos);
    end;
  end;
end;

procedure TLineEditor.Cancel();
begin
  IsCanceled := true;
  Write('^C');
  Inc(CurrPos, 2);
  EndLine();
  WriteLn();
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
  begin
    EndLine();
    WriteLn();
  end;
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

function TLineEditor.EditLine(const Text: string): string;
var
  Key: TKeyEvent;
  KeyString: string;
  KeyChar: Char;
begin
  IsCanceled := false;
  IsTimedOut := false;
  CurrPos := 1;
  if not MaskInput then
  begin
    Line := Text;
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
  if (MinLength > 0) and (TimeoutSecs > 0) then
  begin
    IsTimedOut := not KeyPressedWithinTimeout(TimeoutSecs);
    if IsTimedOut then
    begin
      Enter();
      exit(Line);
    end;
  end;
  KeyChar := #0;
  repeat
    Key := TranslateKeyEvent(GetKeyEvent());
    if IsFunctionKey(Key) then
    begin
      KeyString := Lowercase(KeyEventToString(Key));
      case KeyString of
        'insert':     ToggleInsert();
        'left':       EditCursorLeft(1);
        'right':      EditCursorRight(1);
        'home':       BegLine();
        'end':        EndLine();
        'delete':     DeleteChar();
        'ctrl home':  DeleteToBOL();
        'ctrl end':   DeleteToEOL();
        'ctrl left':  WordLeft();
        'ctrl right': WordRight();
      end; //case
    end
    else
    begin
      KeyChar := GetKeyEventChar(Key);
      if (GetKeyEventFlags(Key) = kbASCII) or (GetKeyEventFlags(Key) = kbUnicode) then
      begin
        case Ord(KeyChar) of
          1: BegLine();      // Ctrl+A
          2: ;
          3: Cancel();       // Ctrl+C
          4: ;
          5: EndLine();      // Ctrl+E
          6..7: ;
          8: Backspace();    // Ctrl+H/Backspace
          9..12: ;
          13: Enter();       // Enter
          14..20: ;
          21, 26: Revert();  // Ctrl+U or Ctrl+Z
          22..25: ;
          27: DeleteLine();  // Esc
          28..31: ;
          127: Backspace();  // Ctrl+Backspace
        else
          begin
            if (DisallowedCharSet = []) or (not (KeyChar in DisallowedCharSet)) then
            begin
              if (AllowedCharSet = []) or (KeyChar in AllowedCharSet) then
                InsertChar(KeyChar);
            end;
          end;
        end; //case
      end
      else if GetKeyEventFlags(Key) = kbPhys then
      begin
        KeyString := Lowercase(KeyEventToString(Key));
        case KeyString of
          'shift key with scancode 2304': Backspace();  // Shift+Backspace
        end; //case
      end;
    end;
  until IsCanceled or InputComplete;
  if IsCanceled then
    result := ''
  else
    result := Line;
end;

initialization

finalization

end.
