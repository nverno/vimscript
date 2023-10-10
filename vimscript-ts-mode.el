;;; vimscript-ts-mode.el --- Tree-sitter support for vimscript -*- lexical-binding: t; -*-

;; This is free and unencumbered software released into the public domain.

;; Author: Noah Peart <noah.v.peart@gmail.com>
;; URL: https://github.com/nverno/vimscript
;; Version: 0.0.1
;; Package-Requires: ((emacs "29.1"))
;; Created:  9 October 2023
;; Keywords: languages vim tree-sitter

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
;;
;;; Installation:
;;
;; ```lisp
;; ```
;;; Code:

(eval-when-compile (require 'cl-lib))
(require 'treesit)

(defcustom vimscript-ts-mode-indent-level 2
  "Number of spaces for each indententation step."
  :group 'vim
  :type 'integer
  :safe 'integerp)

(defface vimscript-ts-mode-register-face
  '((t (:inherit font-lock-variable-name-face :weight bold)))
  "Face to highlight registers in `vimscript-ts-mode'."
  :group 'vim)

(defface vimscript-ts-mode-scope-face
  '((t (:inherit font-lock-type-face :slant italic)))
  "Face to highlight namespaces in `vimscript-ts-mode'."
  :group 'vim)

;;; Syntax

(defvar vimscript-ts-mode--syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?'  "\"" table)
    (modify-syntax-entry ?\" "<"  table)
    (modify-syntax-entry ?\n ">"  table)
    (modify-syntax-entry ?#  "_"  table)
    table)
  "Syntax table in use in Vimscript buffers.")

;;; Indentation

(defvar vimscript-ts-mode--indent-rules
  '((vim
     ((parent-is "script_file") parent 0)
     ((node-is ")") parent-bol 0)
     ((node-is "}") parent-bol 0)
     ((node-is "]") parent-bol 0)
     ((node-is "else") parent-bol 0)
     ((node-is "endif") parent-bol 0)
     ((node-is "endwhile") parent-bol 0)
     ((node-is "endfor") parent-bol 0)
     ((node-is "endfunction") parent-bol 0)
     ((node-is "endfunc") parent-bol 0)
     ((node-is "catch") parent-bol 0)
     ((node-is "endtry") parent-bol 0)
     ((n-p-gp "" "body" "else_statement") grand-parent vimscript-ts-mode-indent-level)
     ((parent-is "body") parent-bol 0)
     (no-node parent-bol vimscript-ts-mode-indent-level)
     (catch-all parent-bol vimscript-ts-mode-indent-level)))
  "Tree-sitter indentation rules for vimscript.")

;;; Font-Lock

(defvar vimscript-ts-mode--feature-list
  '(( comment definition)
    ( keyword string)
    ( assignment property type constant literal operator function escape-sequence)
    ( bracket delimiter variable misc-punctuation error))
  "`treesit-font-lock-feature-list' for `vimscript-ts-mode'.")

(defvar vimscript-ts-mode--operators
  '("||" "&&" "&" "+" "-" "*" "/" "%" ".." "is" "isnot" "==" "!=" ">" ">=" "<"
    "<=" "=~" "!~" "=" "+=" "-=" "*=" "/=" "%=" ".=" "..=" "<<" "=<<")
  "Vimscript operators for tree-sitter font-locking.")

(defvar vimscript-ts-mode--keywords
  '("if" "else" "elseif" "endif"        ; conditionals
    "try" "catch" "finally" "endtry" "throw" ; exceptions
    "for" "endfor" "in" "while" "endwhile" "break" "continue" ; loops
    "function" "endfunction" "return" "range"            ; functions
    ;; filetype
    "detect" "plugin" "indent" "on" "off"
    ;; syntax statement
    "enable" "on" "off" "reset" "case" "spell" "foldlevel" "iskeyword"
    "keyword" "match" "cluster" "region" "clear" "include"
    ;; highlight statement
    "default" "link" "clear"
    ;; command and user-defined commands
    "let" "unlet" "const" "call" "execute" "normal" "set" "setfiletype" "setlocal"
    "silent" "echo" "echon" "echohl" "echomsg" "echoerr" "autocmd" "augroup"
    "return" "syntax" "filetype" "source" "lua" "ruby" "perl" "python" "highlight"
    "command" "delcommand" "comclear" "colorscheme" "startinsert" "stopinsert"
    "global" "runtime" "wincmd" "cnext" "cprevious" "cNext" "vertical" "leftabove"
    "aboveleft" "rightbelow" "belowright" "topleft" "botright"
    "edit" "enew" "find" "ex" "visual" "view" "eval")
  "Vimscript keywords for tree-sitter font-locking.")

(defvar vimscript-ts-mode--font-lock-settings
  (treesit-font-lock-rules
   :language 'vim
   :feature 'comment
   '([(comment) (line_continuation_comment)] @font-lock-comment-face)

   :language 'vim
   :feature 'string
   '([(command) (filename) (string_literal) (pattern)] @font-lock-string-face
     [(pattern_multi)] @font-lock-regexp-face
     (heredoc (body) @font-lock-string-face)
     (colorscheme_statement (name) @font-lock-string-face)
     (syntax_statement (keyword) @font-lock-string-face))
   
   :language 'vim
   :feature 'keyword
   `([,@vimscript-ts-mode--keywords (unknown_command_name)] @font-lock-keyword-face
     (heredoc (parameter) @font-lock-keyword-face)
     (runtime_statement (where) @font-lock-keyword-face)
     (syntax_argument name: _ @font-lock-keyword-face)
     (map_statement cmd: _ @font-lock-keyword-face)
     ["<buffer>" "<nowait>" "<silent>" "<script>" "<expr>" "<unique>"]
     @font-lock-builtin-face)

   :language 'vim
   :feature 'definition
   '((function_declaration
      name: (_) @font-lock-function-name-face)
     (command_name) @font-lock-function-name-face
     (register) @vimscript-ts-mode-register-face
     (default_parameter (identifier) @font-lock-variable-name-face)
     (parameters (identifier) @font-lock-variable-name-face)
     [(no_option) (inv_option) (default_option) (option_name)] @font-lock-variable-name-face
     (bang) @font-lock-negation-char-face
     [(marker_definition) (endmarker)] @font-lock-type-face)
   
   ;; :language 'vim
   ;; :feature 'builtin
   ;; '([(no_option) (inv_option) (default_option) ;; (option_name)
   ;;    ] @font-lock-builtin-face)

   :language 'vim
   :feature 'property
   '((command_attribute
      name: _ @font-lock-property-name-face
      ;; val: (behaviour
      ;;       name: _ @font-lock-constant-face
      ;;       val: (identifier) :? @font-lock-function-name-face)
      ;; :?
      )
     (hl_attribute
      key: _ @font-lock-property-name-face)
     (plus_plus_opt
      val: _ @font-lock-constant-face :?)
     @font-lock-property-name-face
     (plus_cmd) @font-lock-property-name-face)

   :language 'vim
   :feature 'type
   '((augroup_name) @vimscript-ts-mode-scope-face
     (keycode) @font-lock-type-face
     (hl_group) @vimscript-ts-mode-scope-face
     [(scope) "a:" "$"] @vimscript-ts-mode-scope-face)
   
   :language 'vim
   :feature 'constant
   '(((identifier) @font-lock-constant-face
      (:match "\\`[A-Z][A-Z_0-9]*\\'" @font-lock-constant-face))
     (au_event) @font-lock-constant-face
     (normal_statement (commands) @font-lock-constant-face)
     (hl_attribute
      val: _ @font-lock-constant-face))
   
   :language 'vim
   :feature 'literal
   '([(float_literal) (integer_literal)] @font-lock-number-face
     ((set_value) @font-lock-number-face
      (:match "\\`[0-9]+\\(?:\.[0-9]+\\)?\\'" @font-lock-number-face))
     (literal_dictionary (literal_key) @font-lock-constant-face)
     ((scoped_identifier
       (scope) @_scope
       (identifier) @font-lock-constant-face
       (:match "\\(?:true\\|false\\)\\'" @font-lock-constant-face))))
      
   :language 'vim
   :feature 'function
   `((call_expression
      function: (identifier) @font-lock-function-call-face)
     (call_expression
      function: (scoped_identifier (identifier) @font-lock-function-call-face))
     ((set_item
       option: (option_name) @_option
       value: (set_value) @font-lock-function-name-face)
      (:match 
       ,(rx-to-string
         `(seq bos
               (or "tagfunc" "tfu"
                   "completefunc" "cfu"
                   "omnifunc" "ofu"
                   "operatorfunc" "opfunc")
               eos))
       @_option)))
   
   :language 'vim
   :feature 'assignment
   :override 'keep
   '((set_item
      option: (option_name) @font-lock-variable-name-face
      value: (set_value) @font-lock-string-face)
     (let_statement (_) @font-lock-variable-name-face)
     (env_variable (identifier) @font-lock-variable-name-face)
     (map_statement
      lhs: (map_side) @font-lock-variable-name-face
      rhs: _ @font-lock-string-face))

   :language 'vim
   :feature 'operator
   `([(match_case) (bang) (spread) ,@vimscript-ts-mode--operators]
     @font-lock-operator-face
     (unary_operation "!" @font-lock-negation-char-face)
     (binary_operation "." @font-lock-operator-face)
     (ternary_expression ["?" ":"] @font-lock-operator-face)
     (set_item "?" @font-lock-operator-face)
     (inv_option "!" @font-lock-negation-char-face))

   :language 'vim
   :feature 'variable
   '((identifier) @font-lock-variable-use-face)

   :language 'vim
   :feature 'bracket
   '(["(" ")" "{" "}" "[" "]" "#{"] @font-lock-bracket-face)

   :language 'vim
   :feature 'delimiter
   '(["," ";" ":"] @font-lock-delimiter-face
     (field_expression "."  @font-lock-delimiter-face))
   
   :language 'vim
   :feature 'error
   :override t
   '((ERROR) @font-lock-warning-face))
  "Tree-sitter font-lock settings for `vimscript-ts-mode'.")

;;; Navigation

(defun vimscript-ts-mode--defun-name (node)
  "Find name of NODE."
  (treesit-node-text
   (or (treesit-node-child-by-field-name node "name")
       node)))

(defvar vimscript-ts-mode--sentence-nodes nil
  "See `treesit-sentence-type-regexp' for more information.")

(defvar vimscript-ts-mode--sexp-nodes nil
  "See `treesit-sexp-type-regexp' for more information.")

(defvar vimscript-ts-mode--text-nodes
  (rx (or "comment" "string_literal" "filename" "pattern"
          "heredoc" "colorscheme"))
  "See `treesit-text-type-regexp' for more information.")

;;; Imenu

(defvar vimscript-ts-mode--imenu-settings
  `(("Function" "\\`function_declaration\\'")
    ("Command" "\\`command_statement\\'"))
  "See `treesit-simple-imenu-settings' for more information.")

;;;###autoload
(define-derived-mode vimscript-ts-mode prog-mode "Vim"
  "Major mode for vimscript buffers

\\<vimscript-ts-mode-map>"
  :group 'vim
  :syntax-table vimscript-ts-mode--syntax-table
  (when (treesit-ready-p 'vim)
    (treesit-parser-create 'vim)

    ;; Comments
    (setq-local comment-start "\"")
    (setq-local comment-end "")
    (setq-local comment-start-skip "\"+[ \t]*")
    (setq-local parse-sexp-ignore-comments t)

    ;; Indentation
    (setq-local treesit-simple-indent-rules vimscript-ts-mode--indent-rules)

    ;; Font-Locking
    (setq-local treesit-font-lock-feature-list vimscript-ts-mode--feature-list)
    (setq-local treesit-font-lock-settings vimscript-ts-mode--font-lock-settings)
    
    ;; Navigation
    (setq-local treesit-defun-tactic 'top-level)
    (setq-local treesit-defun-name-function #'vimscript-ts-mode--defun-name)
    (setq-local treesit-defun-type-regexp (rx (or "function_definition")))
    
    ;; navigation objects
    (setq-local treesit-thing-settings
                `((vim
                   (sexp ,vimscript-ts-mode--sexp-nodes)
                   (sentence ,vimscript-ts-mode--sentence-nodes)
                   (text ,vimscript-ts-mode--text-nodes))))

    ;; Imenu
    (setq-local treesit-simple-imenu-settings vimscript-ts-mode--imenu-settings)

    (treesit-major-mode-setup)))

(when (treesit-ready-p 'vim)
  (let ((exts (rx (or ".vim" (seq (? (or "." "_")) (? "g") "vimrc") ".exrc") eos)))
    (add-to-list 'auto-mode-alist `(,exts . vimscript-ts-mode))))

(provide 'vimscript-ts-mode)
;; Local Variables:
;; coding: utf-8
;; indent-tabs-mode: nil
;; End:
;;; vimscript-ts-mode.el ends here
