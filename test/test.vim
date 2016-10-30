""""""""""
" test

let tst="a
\ b
\ c"

echo tst

if 1 ||
\ 2
  echom 1
elseif 2
  echom "ann"
endif

"Step through each file...
for filenum in range(filecount)
  " Show progress...
  echo (filenum / filecount * 100) . '% done'" Make progress...
  call process_file(filenum)
endfor
