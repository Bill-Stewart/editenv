# editenv

# Author

Bill Stewart - bstewart at iname.com

# License

**editenv** is covered by the GNU Public License (GPL). See the file `LICENSE` for details.

## Synopsis

**editenv** is a Windows console program that lets you interactively edit the value of an environment variable.

## Usage

**editenv** [_parameter_ [...]] _variablename_

| Parameter                 | Abbrev.    | Description
| ------------------------- | ---------- | ---------------------------------------------
| **--allowedchars=**...    | **-a** ... | Only allows input of specified characters
| **--beginningofline**     | **-b**     | Starts cursor at beginning of line
| **--disallowchars=**...   | **-D** ... | Disallows input of specified characters
| **--disallowquotes**      | **-d**     | Disallows input of `"` character
| **--emptyinputallowed**   | **-e**     | Empty input is allowed to remove variable
| **--help**                | **-h**     | Displays usage information
| **--minlength=**_n_       | **-n** _n_ | Input must be at least _n_ character(s)
| **--maxlength=**_n_       | **-x** _n_ | Input cannot be longer than _n_ character(s)
| **--maskinput**[**=**_x_] | **-m** _x_ | Masks input using character _x_ (default=`*`)
| **--overtypemode**        | **-o**     | Starts line editor in overtype mode
| **--prompt=**...          | **-p** ... | Specifies an input prompt
| **--quiet**               | **-q**     | Suppresses error messages
| **--timeout=**_n_         | **-t** _n_ | Automatically enter input after _n_ second(s)

### Remarks

* _variablename_ specifies the name of the environment variable you want to edit.

* Parameter names are case-sensitive.

* If the environment variable name or an argument to one of the above parameters contains spaces, enclose it in double quote (`"`) characters.

* The **--maskinput** (**-m**) parameter supports an optional argument (character to use for masking). The full parameter name (**--maskinput**) does not require the mask character, but the abbreviated parameter name (**-m**) requires you to specify a character (that is, `--maskinput` and `-m *` are equivalent). If you want to specify a space for the mask character, specify `--maskinput=" "` or `-m " "`.

* If you specify both **--minlength** (**-n**) and **--maxlength** (**-x**), the minimum length must be smaller than the maximum length.

* You cannot specify the **--minlength** (**-n**) parameter with either the **--emptyinputallowed** (**-e**) or **--timeout** (**-t**) parameters.

* An argument of `0` for **--maxlength** (**-x**) means "no maximum length" (up to maximum allowed length: See **Notes/Limitations** section, below).

* It is recommended to specify parameters at the beginning of the command line (in any order) and the environment variable name at the end of the command line.

## Line Editor

The line editor supports the following keystroke commands:

| Key                       | Action
| ------------------------- | ------------------------------------------------
| `Left`, `Right`           | Moves cursor left or right
| `Home` or `Ctrl+A`        | Moves cursor to beginning of line
| `End` or `Ctrl+E`         | Moves cursor to end of line
| `Ctrl+Left`, `Ctrl+Right` | Moves cursor left or right one word
| `Insert`                  | Toggle between insert and overtype mode
| `Delete`                  | Deletes the character under the cursor
| `Backspace` or `Ctrl+H`   | Deletes the character to the left of the cursor
| `Ctrl+Home`               | Deletes to the beginning of the line
| `Ctrl+End`                | Deletes to the end of the line
| `Esc` or `Ctrl+[`         | Deletes the entire line
| `Ctrl+U` or `Ctrl+Z`      | Reverts line to original value
| `Ctrl+C`                  | Cancel input
| `Enter` or `Ctrl+M`       | Enter input

### Remarks

The `Enter` key does nothing if you use the **--minlength** (**-n**) parameter and the length of the input string is fewer than the number of characters specified by the parameter. (You may want to indicate this in the input prompt.)

## Exit Codes

| Description                                                        | Exit Code
| ------------------------------------------------------------------ | ---------
| No error                                                           | 0
| Empty input and **--emptyinputallowed** (**-e**) not specified     | 13
| Command line contains an error                                     | 87
| Environment variable name or value are too long                    | 122
| Cannot use **--maskinput** (**-m**) parameter when variable exists | 183
| Current and parent process must both be 32-bit or 64-bit           | 216
| **--timeout** (**-t**) period elapsed                              | 258
| `Ctrl+C` pressed to cancel input                                   | 1223

### Remarks

* In cmd.exe, you can check the exit code using the `%ERRORLEVEL%` variable or the `if errorlevel` command.

* In PowerShell, you can check the exit code using the `$LASTEXITCODE` variable.

## Notes/Limitations

* The environment variable's name cannot contain the `=` character.

* The environment variable's name is limited to 127 characters.

* The environment variable's value is limited to 16383 characters.

* The **--timeout** (**-t**) parameter does not use a high-precision timer.

* The **--maskinput** (**-m**) parameter is not encrypted or secure.

* There is no visual indication of insert vs. overtype mode.

* **editenv** does not work from the PowerShell ISE.

## Examples

1.  Edit the `Path` environment variable for the current console:

        editenv Path

    When you enter this command, `editenv` lets you interactively edit the `Path` environment variable for the current console process.

2.  cmd.exe shell script (batch file):

        @echo off
        setlocal enableextensions
        :REPEAT
        set _NAME=%USERNAME%
        editenv --prompt="Enter your name: " --quiet _NAME
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

    This script prompts you to enter your name and uses the value of the `%USERNAME%` environment variable as the initial value. If you press `Ctrl+C`, the script outputs "You canceled". If you pressed `Enter` on an empty input line, the script outputs "You didn't enter your name" and repeats the prompt.

3.  cmd.exe shell script:

        @echo off
        setlocal enableextensions
        :REPEAT
        set _PIN=
        editenv --allowedchars=0123456789 --minlength=4 --maxlength=8 --maskinput --prompt="Enter PIN (4-8 digits): " --quiet _PIN
        if %ERRORLEVEL% EQU 1223 goto :REPEAT
        if %ERRORLEVEL% EQU 13 goto :REPEAT
        echo You entered: %_PIN%
        endlocal

    This script prompts you to enter a number from 4 to 8 digits long. Pressing `Ctrl+C` without entering a value repeats the prompt. (The `Enter` key does nothing if the input line has fewer than 4 characters because the command line specifies `--minlength=4`.)

4.  PowerShell script:

        $env:_ANS = "N"
        do {
          editenv --prompt="Are you sure? [Y/N] " --allowedchars=NnYy --beginningofline --maxlength=1 --overtype --quiet --timeout=20 _ANS
        } until ( $LASTEXITCODE -ne 13 )
        if ( $LASTEXITCODE -ne 1223 ) {
          if ( $env:_ANS -eq "Y" ) {
            "You said yes"
          }
          else {
            "You said no"
          }
        }
        $env:_ANS = $null

    This script presents a timed prompt to enter a `Y` or `N` answer. If you don't enter anything within 20 seconds, `N` is assumed. Otherwise, you can enter a `Y` or `N` response. If you enter empty input, the prompt repeats. Pressing `Ctrl+C` skips the output statements.
