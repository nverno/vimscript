;;; vimscript --- Major mode for vimscript

;; Author: Noah Peart <noah.v.peart@gmail.com>
;; URL: https://github.com/nverno/vimscript
;; Package-Requires: 
;; Copyright (C) 2016, Noah Peart, all rights reserved.
;; Created: 29 October 2016

;; This file is not part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.

;;; Commentary:

;; [![Build Status](https://travis-ci.org/nverno/vimscript.svg?branch=master)](https://travis-ci.org/nverno/vimscript)

;;; Code:
(eval-when-compile
  (require 'vimscript-keywords)
  (require 'cl-lib)
  ;; (require 'dash)
  )

(defgroup vimscript nil
  "Major mode for editing Vim script files."
  :group 'languages)

(defcustom vimscript-indent-offset 2
  "Default indentation level to use in `vimscript-mode'."
  :group 'vimscript-mode
  :type 'integer)

(defvar vimscript-use-smie t
  "When non-nil use `smie' for indentation.")

;; ------------------------------------------------------------

;;; Indentation

(require 'smie)


(defconst vimscript-smie-grammar
  (smie-prec2->grammar
   (smie-merge-prec2s
    (smie-bnf->prec2
     '((id)
       (inst (exp))
       (exp (exp1) (exp "=" exp))
       (exp1 (exp2) (exp2 "?" exp1 ":" exp1))
       (exp2 ("if" exp "endif")
            ("if" exp "else" exp "endif")
            ("if" exp "elseif" exp "endif")
            ("if" exp "elseif" exp "else" exp "endif")
            ("try" exp "catch" exp "endtry")
            ("function" exp "endfunction")
            ("while" exp "endwhile")    
            ("for" exp "endfor")
            ("[" listvals "]")
            ("{" hashvals "}"))
       (listvals (exp1 "," exp1) (listvals "," listvals))
       (hashvals (exp1 ":" exp1) (hashvals "," hashvals)))
     '((assoc ",") (assoc ";") (nonassoc ":") (right "=")))
    (smie-precs->prec2
     '((right "=")
       (left "&&" "||")
       (left "+" "-")
       (left "*" "/" "%")
       (assoc "."))))))

(defun vimscript-smie-rules (kind token)
  (pcase (cons kind token)
    (`(:elem . basic) vimscript-indent-offset)
    (`(:elem . args) 0)
    ;; (`(:close-all . ,_) t)
    ;; (`(:list-intro . ,(or `"" `"\n")) t)
    ;; (`(:before . ""))

    ;; (`(:after . ,(or `"(" "[" "{"))
    ;;  (save-excursion
    ;;    (forward-char 1)
    ;;    (skip-chars-forward " \t")
    ;;    (unless (or (eolp) (forward-char 1))
    ;;      (cons 'column (current-column)))))
    ))

(defun vimscript-smie--backward-token ()
  (let ((tok (smie-default-backward-token)))
    (cond
     ((and (equal tok "")
           (looking-back "[ \t]*\\\\[ \t]*" (line-beginning-position)))
      (goto-char (match-beginning 0))
      (vimscript-smie--backward-token))
     (t tok))))

;;; Completion

(eval-and-compile
 (defvar vimscript--kw-no-option
   (eval-when-compile
     (cl-loop for k in kw-no-option
       do (setq k (concat "no" k))
         (put-text-property 0 1 'annot "Option" k)
        collect k)))

 (defvar vimscript--keywords
   (eval-when-compile
     `(,vimscript--kw-no-option
       ,@(cl-loop for k in kw-option
            do (put-text-property 0 1 'annot "Option" k)
            collect k)
       ,@(cl-loop for k in kw-ex-command
            do (put-text-property 0 1 'annot "Ex Command" k)
            collect k)
       ,@(cl-loop for k in kw-function
            do (put-text-property 0 1'annot "Function" k)
            collect k)))))

(defun vimscript-capf-annotation (candidate)
  (or (get-text-property 0 'annot candidate) ""))

(defun vimscript-complete-at-point ()
  (let* ((bnds (bounds-of-thing-at-point 'symbol))
         (beg (car bnds))
         (end (cdr bnds)))
    (when bnds
      (cond
       ((and (eq (char-after beg) ?n)
             (eq (char-after (1+ beg)) ?o))
        (list beg end vimscript--kw-no-option
              :annotation-function 'vimscript-capf-annotation))
       (t
        (list beg end vimscript--keywords
              :annotation-function 'vimscript-capf-annotation))))))

;;; Syntax

(defvar vimscript-mode-syntax-table
  (let ((st (make-syntax-table)))
    (modify-syntax-entry ?\" "." st)
    (modify-syntax-entry ?\n ">" st)
    (modify-syntax-entry ?\" "\"\"" st)
    (modify-syntax-entry ?\' "\"\"" st)
    st))

;;; Font-locking

(defun vimscript-line-continued-p ()
  (save-excursion
    (beginning-of-line)
    (looking-at-p "[ \t:]*\\\\")))

;; modify syntax for strings / comments
(defun vimscript-syntax-propertize-function (start end)
  (goto-char start)
  (funcall
   (syntax-propertize-rules
    ("^\\s-*\\(\"\\)" (1 "<"))
    ("\"\\([^\"\n\r]*\\)$"
     (0 (prog1 nil
          ;; when trailing syntax after final '"' on line is string,
          ;; convert to comment
          (when (save-excursion
                  (and (eq (char-after (match-beginning 0)) ?\")
                       (nth 3 (syntax-ppss (match-beginning 2)))
                       ;; don't commentify if string continued with '\'
                       ;; on next line
                       (zerop (forward-line 1))
                       (not (vimscript-line-continued-p))))
            (let ((start (match-beginning 0))
                  (end (match-end 0)))
              ;; "<" ... ">" syntax '(11) ... '(12)
              (put-text-property start (1+ start) 'syntax-table '(11))
              (put-text-property end (1+ end) 'syntax-table '(12))))))))
   (point) end))

;; faces/default font-locking from `vimrc-mode'

(defface vimscript-option
  '((default :inherit font-lock-variable-name-face))
  "Face used for Vim's configuration options.")

(defface vimscript-function-builtin
  '((default :inherit font-lock-builtin-face))
  "Face used for Vim's built-in functions.")

(defface vimscript-command
  '((default :inherit font-lock-keyword-face))
  "Face used for Vim Ex commands.")

(defface vimscript-number
  '((((class color) (background light)) (:foreground "steel blue"))
    (((class color) (background dark)) (:foreground "sky blue"))
    (t nil))
  "Face used for Vim's numbers.")

(defvar vimscript-font-lock-keywords
  (eval-when-compile
    `( ;; Function-name start:
     ("^[ \t]*\\(fun\\(?:ction\\)?\\)!?[ \t]+\\([a-zA-Z0-9_:#]+\\)?"
      (2 font-lock-function-name-face nil t)) ;; Function-name end;
     ("\\(\\([a-zA-Z]*:\\)?[a-zA-Z]*\\)("
      (1 font-lock-function-name-face nil t)) ;; Function-name end;

     ;; Variables
     ("\\<[bwglsav]:[a-zA-Z_][a-zA-Z0-9#_]*\\>"
      (0 font-lock-variable-name-face))
     ("\\(let[ \t]+\\)\\<\\([a-zA-Z_][a-zA-Z0-9#_]*\\)\\>"
      (2 font-lock-variable-name-face))

     ;; Options which can be prefixed with `no'
     (,(concat "[^_]\\<\\(\\(?:no\\)?" (regexp-opt kw-no-option t)
               "\\)\\>[^_]" )
      1 '(face vimscript-option))

     ;; The rest of the options
     (,(concat "[^_]" (regexp-opt kw-option 'words) "[^_]")
      1 '(face vimscript-option))

     ;; Ex commands
     (,(concat "\\(^\\|[^_]\\)" (regexp-opt kw-ex-command 'words)
               "\\([^_]\\|$\\)")
      2 '(face vimscript-command))

     ;; Built-in functions
     (,(concat "\\(^\\|[ \t]*\\)" (regexp-opt kw-function 'words)
               "\\([ \t]*(\\)")
      2 '(face vimscript-function-builtin))

     ;; Numbers
     ("\\<0[xX][[:xdigit:]]+"
      (0 '(face vimscript-number)))
     ("#[[:xdigit:]]\\{6\\}"
      (0 '(face vimscript-number)))
     (,(concat
        "\\(\\<\\|-\\)[[:digit:]]+"
        "\\(\\.[[:digit:]]+\\([eE][+-]?[[:digit:]]+\\)?\\)?")
      0 '(face vimscript-number))

     ;; Operators start:
     (,(concat "\\("
               ;; word char
               "\\(\\<isnot\\>\\)"
               "\\|" "\\(\\<is\\>\\)"

               "\\|" "\\(![=~]?[#?]?\\)"
               "\\|" "\\(>[#\\\\?=]?[#?]?\\)"
               "\\|" "\\(<[#\\\\?=]?[#?]?\\)" 
               "\\|" "\\(\\+=?\\)"
               "\\|" "\\(-=?\\)"
               "\\|" "\\(=[=~]?[#?]?\\)"
               "\\|" "\\(||\\)"
               "\\|" "\\(&&\\)"

               "\\|" "\\(\\.\\)"
               "\\)"
               )
      1 font-lock-constant-face) ;; Operators end;
     ))
  "Default expressions to highlight in vimscript mode.")

;;; Imenu

(defvar vimscript-imenu-generic-expression
  '((nil "^\\(fun\\(?:ction\\)?\\)!?[[:blank:]]+\\([[:alnum:]_:#]+\\)?" 2)
    (nil "^let[[:blank:]]+\\<\\([bwglsav]:[a-zA-Z_][[:alnum:]#_]*\\)\\>" 1)
    (nil "^let[[:blank:]]+\\<\\([a-zA-Z_][[:alnum:]#_]*\\)\\>[^:]" 1))
  "Value for `imenu-generic-expression' in Vimrc mode.

Create an index of the function and variable definitions in a
Vim file.")

(defun vimscript-beginning-of-defun (&optional arg)
  "Move backward to the beginning of the current function.

With argument, repeat ARG times."
  (interactive "p")
  (re-search-backward (concat  "^[ \t]*\\(fun\\(?:ction\\)?\\)\\b")
                      nil 'move (or arg 1)))

(defun vimscript-end-of-defun (&optional arg)
  "Move forward to the next end of a function.

With argument, repeat ARG times."
  (interactive "p")
  (re-search-forward (concat  "^[ \t]*\\(endf\\(?:unction\\)?\\)\\b")
                     nil 'move (or arg 1)))

(defun vimscript-reload ()
  (interactive)
  (unload-feature 'vimscript)
  (require 'vimscript)
  (vimscript-mode))

(defvar vimscript-mode-map
  (let ((km (make-sparse-keymap)))
    (define-key km (kbd "<f2> m r") #'vimscript-reload)
    km))

;;;###autoload
(define-derived-mode vimscript-mode prog-mode "Vimscript"
  "Major mode for editing vimscript (.vimrc) files."
  (setq-local font-lock-defaults '(vimscript-font-lock-keywords))
  (setq-local syntax-propertize-function #'vimscript-syntax-propertize-function)
  (setq-local comment-start "\"")
  (setq-local comment-end "")
  ;;(set (make-local-variable 'comment-start-skip) "\"\\* +")
  (setq-local imenu-generic-expression vimscript-imenu-generic-expression)
  (setq-local beginning-of-defun-function 'vimscript-beginning-of-defun)
  (setq-local end-of-defun-function 'vimscript-end-of-defun)

  ;; indentation
  (when vimscript-use-smie
    (smie-setup vimscript-smie-grammar #'vimscript-smie-rules
                :forward-token #'smie-default-forward-token
                :backward-token #'vimscript-smie--backward-token))

  ;; completion
  (add-hook 'completion-at-point-functions
            'vimscript-complete-at-point nil 'local))

;;;###autoload (add-to-list 'auto-mode-alist '("\\.vim\\'" . vimscript-mode))
;;;###autoload (add-to-list 'auto-mode-alist '("[._]?g?vimrc\\'" . vimscript-mode))
;;;###autoload (add-to-list 'auto-mode-alist '("\\.exrc\\'" . vimscript-mode))

(provide 'vimscript)
;;; vimscript.el ends here
