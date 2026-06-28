;;; pydor.el --- Provide command to run the Python doctest at point

;; Author: P.C.J. Swinkels <swinkels.pieter@yahoo.com>
;; Created: 27 July 2023

;; Version: 0.0.0
;; Package-Version: 20231024.205440

;; URL: https://github.com/swinkels/pydor

;;; Commentary:

;; Needs to be filled in, for now only present to satisfy the lint...

;;; Code:

(provide 'pydor)

(defvar pydor-pythonpath-directories nil
  "list of absolute directory paths to search for module files.

The paths in this list will be added to the search path before
the module with the doctests is loaded.")

(defcustom pydor nil
  "Run Python doctests at point"
  :group 'Tools)

(defcustom pydor-run-verbose nil
  "True if and only if the Python script runs with verbose logging.

Verbose logging means that the Python script runs with log level
DEBUG. If the value is false, the script runs with log level
INFO."
  :type 'boolean :group 'pydor)

(defvar pydor--install-directory
  (file-name-directory (if load-file-name load-file-name buffer-file-name))
  "*Path to the directory that contains the current package.

This directory also contains the Python script that finds the
doctests and runs the selected one. This allows us to call that
script from anywhere")

(defun pydor--delimits-multiline-docstring(line)
  (not (eq (string-match-p "^[[:blank:]]*r?\"\"\"" line) nil)))

(defun pydor--current-line()
  (buffer-substring-no-properties (line-beginning-position) (line-end-position)))

(defun pydor--build-pythonpath-parameters()
  (mapconcat
   (lambda (x) (concat " --pythonpath " x)) pydor-pythonpath-directories ""))

(defun pydor--build-verbose-parameter()
  (if pydor-run-verbose
      " --verbose"
    ""))

(defun pydor--move-to-previous-line()
  (eq (forward-line -1) 0))

(defun pydor--find-delimiter-multiline-docstring()
  (save-excursion
    (while (and (not (pydor--delimits-multiline-docstring (pydor--current-line)))
                (pydor--move-to-previous-line))
      nil)
    (if (pydor--delimits-multiline-docstring (pydor--current-line))
        (line-number-at-pos)
      -1)))

(defun pydor--build-execute-doctest-spec()
  (let ((lineno (pydor--find-delimiter-multiline-docstring)))
    (when (> lineno 0)
        (concat "python " pydor--install-directory "execute_doctests.py "
                (buffer-file-name)
                " "
                (number-to-string lineno)))))

(defun pydor-execute-doctest()
  (interactive)
  (let ((call-script-command (pydor--build-execute-doctest-spec)))
    (if call-script-command
        (compile
         (concat
          call-script-command
          (pydor--build-pythonpath-parameters)
          (pydor--build-verbose-parameter)))
      (message "Did not find a doctest"))))

;;; pydor.el ends here
