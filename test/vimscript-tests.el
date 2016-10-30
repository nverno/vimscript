(require 'vimscript)
(require 'ert)

(defmacro vimscript--should-indent (from to)
  `(with-temp-buffer
     (let ((vimscript-indent-offset 2))
       (vimscript-mode)
       (insert ,from)
       (indent-region (point-min) (point-max))
       (should (string= (buffer-substring-no-properties (point-min) (point-max))
                      ,to)))))

(ert-deftest vimscript--test-indent-if-1 ()
  "if"
  (vimscript--should-indent
   "
if 0
  0
endif"
   "
if 0
  0
endif"))

(ert-deftest vimscript--test-indent-if-2 ()
  "if else"
  (vimscript--should-indent
   "
if 0
0
else
1
endif"
   "
if 0
  0
else
  1
endif"))

(ert-deftest vimscript--test-indent-if-3 ()
  "if esleif else"
  (vimscript--should-indent
   "
if 0
0
elseif 1
1
else
2
endif"
   "
if 0
  0
elseif 1
  1
else
  2
endif"))

(ert-deftest vimscript--test-indent-while ()
  "while"
  (vimscript--should-indent
   "
while i < 5
echo i
let i += 1
endwhile"
   "
while i < 5
  echo i
  let i += 1
endwhile"))

(ert-deftest vimscript--indent-for ()
  "for"
  "
for i in range(1, 4)
other stmt
echo i
endfor"
  "
for i in range(1, 4)
  other stmt
  echo i
endfor")

(defun vimscript--run-tests ()
  (interactive)
  (if (featurep 'ert)
      (ert-run-tests-interactively "vimscript--test")
    (message "cant run without ert.")))

(provide 'vimscript-tests)
