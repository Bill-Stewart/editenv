 EditEnv

**EditEnv** allows interactive editing of an environment variable in a Windows console.

## Copyright and Author

Copyright (C) 2020-2025 by Bill Stewart (bstewart at iname.com)

## License

**EditEnv** is covered by the GNU Public License (GPL). See the file `LICENSE` for details.

## Download

https://github.com/Bill-Stewart/editenv/releases

## Version History

See the file `history.md`.

## Usage

**EditEnv** [_parameter_ [...]] _variablename_

| Parameter                 | Abbrev.    | Description
| ---------                 | -------    | -----------
| **--allowedchars=**...    | **-a** ... | Only allows input of specified characters
| **--beginningofline**     | **-b**     | Starts cursor at beginning of line
| **--disallowchars=**...   | **-d** ... | Disallows input of specified characters
| **--emptyinputallowed**   | **-e**     | Empty input is allowed to remove variable
| **--help**                | **-h**     | Displays usage information
| **--minlength=**_n_       | **-n** _n_ | Input must be at least _n_ character(s)
| **--maxlength=**_n_       | **-x** _n_ | Limit input length to _n_ character(s)
| **--maskinput**[**=**_c_] | **-m** _c_ | Masks input using character _c_ (default=`*`)
| **--overtypemode**        | **-o**     | Starts line editor in overtype mode
| **--prompt=**...          | **-p** ... | Specifies an input prompt
| **--quiet**               | **-q**     | Suppresses error messages
| **--timeout=**_n_         | **-t** _n_ | Automatically enter input after _n_ second(s)

### Remarks

* **EditEnv** presents the value of the environment variable for interactive editing in the console (see the **Line Editor** section, below). When you press **Enter**, **EditEnv** sets the value of the environment variable in its parent process. This only works if the current process and parent process are both 32-bit or 64-bit. **EditEnv** does not perform any registry modifications.

* **EditEnv** supports Unicode. For best results, it's recommended to use UTF8 encoding for input and output in the console (see the **Unicode Support** section, below).

* _variablename_ specifies the name of the environment variable you want to edit.

* Parameter names are case-sensitive.

* If the environment variable name or an argument to one of the above parameters contains spaces, enclose it in double quote (`"`) characters.

* To embed a double quote (`"`) character in a quoted string, double the `"` character inside the quoted string.

* The **--maskinput** parameter supports an optional argument that specifies the character to use for masking. The default mask character is the asterisk (`*`). To specify a space as the mask character, specify `--maskinput=" "`. If you specify **-m** rather than **--maskinput**, you must specify a mask character (i.e., `-m *`).

* If you specify both **--minlength** (**-n**) and **--maxlength** (**-x**), the maximum length must be greater than or equal to the minimum length.

* You cannot specify the **--minlength** (**-n**) parameter with either the **--emptyinputallowed** (**-e**) or **--timeout** (**-t**) parameters.

* An argument of `0` for **--maxlength** (**-x**) means "maximum allowable length" (see the **Maximum Input Length** section, below).

* It is recommended to specify parameters at the beginning of the command line (in any order) and the environment variable name at the end of the command line.

## Line Editor

The line editor supports the following keystroke commands:

| Key                            | Action
| ---                            | ------
| **Left**, **Right**            | Moves cursor left or right
| **Home** or **Ctrl+A**         | Moves cursor to beginning of line
| **End** or **Ctrl+E**          | Moves cursor to end of line
| **Ctrl+Left**, **Ctrl+Right**  | Moves cursor left or right one word
| **Insert**                     | Toggle between insert and overtype mode
| **Delete**                     | Deletes the character under the cursor
| **Backspace** or **Ctrl+H**    | Deletes the character to the left of the cursor
| **Ctrl+Home**                  | Deletes to the beginning of the line
| **Ctrl+End**                   | Deletes to the end of the line
| **Esc** or **Ctrl+[**          | Deletes the entire line
| **Ctrl+U** or **Ctrl+Z**       | Reverts line to original value
| **Ctrl+V** or **Shift+Insert** | Pastes clipboard text
| **Ctrl+C** or **Ctrl+Break**   | Cancel input
| **Enter** or **Ctrl+M**        | Enter input

### Remarks

* When using **--maskinput** (**-m**), the only available key commands in the above table are **Backspace**/**Ctrl+H** and **Esc**/**Ctrl+[**.

* The **Enter** key does nothing if you use the **--minlength** (**-n**) parameter and the length of the input string is fewer than the number of characters specified by the parameter. (You may want to indicate this in the input prompt.)

* The clipboard paste action (**Ctrl+V** or **Shift+Insert**) replaces control characters (including newlines) with spaces when pasting. If **--allowedchars** (**-a**) or **--disallowchars** (**-d**) are in effect, only allowed characters will be pasted.

* **EditEnv** will not "see" any keystroke commands managed by the console session in which it's running. For example: By default, Windows Terminal (WT) handles the **Ctrl+V** keystroke. This means that unless you change the default, pressing **Ctrl+V** will execute the WT paste action rather than the **EditEnv** paste action.

## Exit Codes

Exit Code | Description
--------- | -----------
0         | No error
6         | EditEnv does not work from the PowerShell ISE
13        | Empty input and **--emptyinputallowed** (**-e**) not specified
87        | Command line contains an error
122       | Environment variable name or value are too long
183       | Cannot use **--maskinput** (**-m**) parameter when variable exists
216       | Current and parent process must both be 32-bit or 64-bit
258       | **--timeout** (**-t**) period elapsed
1223      | **Ctrl+C** or **Ctrl+Break** pressed to cancel input

### Remarks

* In cmd.exe, you can check the exit code using the **ERRORLEVEL** variable or the `if errorlevel` command.

* In PowerShell, you can check the exit code using the **$LASTEXITCODE** variable.

## Maximum Input Length

The maximum possible number of input characters depends on whether the current session is a standard Windows console or a Windows Terminal (WT) console.

* In a standard Windows console, the maximum possible number of input characters is the number of rows * the number of columns in the console buffer or 16383, whichever is less. The standard Windows console allows the cursor to move back past the top of the current screenful into the scrollback buffer, which means it is possible to edit an environment variable that has a value longer than will fit in the current screenful.

* In a WT console, the maximum possible number of input characters is the number of rows * the number of columns or 16383 (whichever is less) in the current screenful only. WT does not allow the cursor to move "backwards" past the top of the current screenful into the scrollback buffer, which means it is not possible to edit an environment variable that has a value longer than will fit in the current screenful. You can work around this limitation in a WT session by expanding the WT window such that it has a larger number of rows and/or columns before running **EditEnv**.

## Unicode Support

**EditEnv** supports Unicode. For best results, it's recommended to use UTF8 encoding for input and output in the console and to use a terminal font typeface that supports Unicode (such as Consolas).

* In cmd.exe, you enable UTF8 encoding by running the following command:
  
      chcp 65001

* In PowerShell, you can enable UTF8 encoding by running the following command:

      $OutputEncoding = [Console]::InputEncoding =
        [Console]::OutputEncoding =
        New-Object Text.UTF8Encoding

## Notes/Limitations

* The environment variable's name cannot contain the `=` character.

* The environment variable's name is limited to 127 characters.

* The **--timeout** (**-t**) parameter does not use a high-precision timer.

* The **--maskinput** (**-m**) parameter is not encrypted or secure.

* The **--allowedchars** (**-a**) and **--disallowchars** (**-d**) parameters cannot contain control characters in the ASCII range 0-32 or 127.

* There is no visual indication of insert vs. overtype mode.

* **EditEnv** does not work from the PowerShell ISE.

* The maximum possible input length depends on whether **EditEnv** is running in a standard Windows console or a Windows Terminal (WT) console (see the **Maximum Input Length** section, above).

* Unicode characters that occupy more than one character of screen space are not supported.

* Resizing the window while **EditEnv** is running may cause unexpected cursor positioning behavior and movement.

## Examples

1.  Edit the **Path** environment variable for the current console:

        EditEnv Path

    When you enter this command, **EditEnv** lets you interactively edit the **Path** environment variable for the current console process.

2.  cmd.exe shell script (batch file):

        @echo off
        setlocal enableextensions
        :REPEAT
        set _NAME=%USERNAME%
        EditEnv --prompt="Enter your name: " --quiet _NAME
        if %ERRORLEVEL% EQU 1223 goto :CANCEL
        if %ERRORLEVEL% EQU 13 goto :NOEMPTY
        echo Hello, %_NAME%
        goto :DONE
        :CANCEL
        echo You canceled
        goto :DONE
        :NOEMPTY
        echo You didn't enter your name
        goto :REPEAT
        :DONE
        endlocal

    This script prompts you to enter your name and uses the value of the **USERNAME** environment variable as the initial value. If you press **Ctrl+C**, the script outputs "You canceled". If you pressed **Enter** on an empty input line, the script outputs "You didn't enter your name" and repeats the prompt.

3.  cmd.exe shell script:

        @echo off
        setlocal enableextensions
        :REPEAT
        set _PIN=
        EditEnv -a 0123456789 -n 4 -x 8 -m * -p "PIN (4-8 digits): " -q _PIN
        if %ERRORLEVEL% EQU 1223 goto :REPEAT
        if %ERRORLEVEL% EQU 13 goto :REPEAT
        echo You entered: %_PIN%
        endlocal

    This script prompts you to enter a number from 4 to 8 digits long. Pressing **Ctrl+C** without entering a value repeats the prompt. (The **Enter** key does nothing if the input line has fewer than 4 characters because the command line specifies `-n 4`.)

4.  PowerShell script:

        $env:_ANS = "N"
        EditEnv -p "Are you sure? [Y/N] " -a NnYy -b -x 1 -o -q -t 20 _ANS
        if ( $LASTEXITCODE -ne 1223 ) {
          if ( $env:_ANS -eq "Y" ) {
            "You said yes"
          }
          else {
            "You said no"
          }
        }
        Remove-Item env:_ANS

    This script presents a timed prompt to enter a **Y** or **N** answer. If you don't enter anything within 20 seconds, **N** is assumed. Otherwise, you can enter a **Y** or **N** response. Pressing **Ctrl+C** skips the output statements.
