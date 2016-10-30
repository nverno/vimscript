" -*- mode: vimscript -*-

" Conditionals
let a = 1
        if has("win32") || has("win16")
                      let s:a = "win"
      echo s:a
else
  let s:a = "o"
      echo s:a
endif

if !exists("s:a")
    let s:a = 0
    echo s:a
elseif 3 || 4
         echo
         let s:a = "hi"
else
  echo
  set a=3
endif

echo i > 5 ? "i >5" : "i<=5" " ternary

" Loops

" while {condition}
"   {statements}
" endwhile

let i = 1
while i < 5
        echo "count is" i
        let i += 1
endwhile

for i in range(1, 4)
      echo i
endfor

" Functions (names start with capital)

" function {name}({var1}, {var2} ,...)
"   {body}
" endfunction

function! Min(num1, num2)
          if a:num1 < a:num2
              let smaller = a:num1
          else
            let smaller = a:num2
          endif
          return smaller
endfunction

function! Min(num1, num2)
          return num1
endfunction

function! Count_words() range
          let lnum = afirstline
          let n = 0
          while lnum <= alastline
                     let n = n + len(split(getline(lnum)))
                     let lnum = lnum + 1
          endwhile
          echo "found " . n . " words"
endfunction

function! Tst(num1, num2)
          return num1 + num2
          endfunc
          
          " augroup filetypedetect
          " au! BufNewFile,BufRead *.json setf javascript
          "                        augroup END
