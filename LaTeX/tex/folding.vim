"-------------------------------------------------------------------
" Author(s)     : Mahbub Alam
" Created       : ~30/05/2018
" License       : MIT
" Description   : Folding in LaTeX-Box or in vimtex like in LaTeX-Suite
"-------------------------------------------------------------------

" Folding in LaTeX-Box or in vimtex like in LaTeX-Suite{{{

" My modification of @petobens (https://tex.stackexchange.com/users/9953/petobens) folding method.

" I've (@petobens https://tex.stackexchange.com/users/9953/petobens) modified Latex-Box (excellent) folding in two ways: i) since I only like to fold sections (parts, chapters, etc), the abstract environment and frames (in beamer class) I've added a new variable g:LatexBox_folded_environments that controls which environments are folded ii) I changed the LatexBox_FoldText() to resemble Latex-Suite.

"You should save this file as ftplugin/tex/folding.vim and it should work out of the box.

" If you want to fold other environments add them at Set options and LaTeXBox_FoldText part. (Can't say anything about the next paragraph)

" If you want to fold figures, tables and other environments you should add the functions LabelEnv(), CaptionEnv() and CaptionTable() from LaTeX-Box/ftplugin/latex-box/folding.vim and modify the LatexBox_FoldText() function to include the mentioned functions as its done in Latex-Box folding (but changing the format to the format that suits your needs).

"}}}

" Initialization {{{

if exists('b:loaded_mylatexfolding')
    finish
endif
let b:loaded_mylatexfolding=0

" }}}
" Set options {{{

setlocal foldmethod=marker
setlocal foldexpr=LatexBox_FoldLevel(v:lnum)
setlocal foldtext=LatexBox_FoldText()

if !exists('g:LatexBox_fold_preamble')
    let g:LatexBox_fold_preamble=1
endif

" if !exists('g:LatexBox_fold_preamble_parts')
"     let g:LatexBox_fold_preamble_parts=1
" endif

if !exists('g:LatexBox_fold_parts')
    let g:LatexBox_fold_parts=[
                \ "appendix",
                \ "frontmatter",
                \ "mainmatter",
                \ "backmatter"
                \ ]
endif

if !exists('g:LatexBox_fold_sections')
    let g:LatexBox_fold_sections=[
                \ "part",
                \ "chapter",
                \ "section",
                \ "subsection",
                \ "subsubsection"
                \ ]
endif

if !exists('g:LatexBox_fold_envs')
    let g:LatexBox_fold_envs=1
endif
if !exists('g:LatexBox_folded_environments')
    let g:LatexBox_folded_environments = [
                \ "abstract",
                \ "lemma",
                \ "ulemma",
                \ "proposition",
                \ "uproposition",
                \ "theorem",
                \ "utheorem",
                \ "corollary",
                \ "ucorollary",
                \ "proof",
                \ "remark",
                \ "uremark",
                \ "frame"
                \ ]
endif

" }}}
" LatexBox_FoldLevel helper functions {{{

" This function parses the tex file to find the sections that are to be folded
" and their levels, and then predefines the patterns for optimized folding.
function! s:FoldSectionLevels()
    " Initialize
    let level = 1
    let foldsections = []

    " If we use two or more of the *matter commands, we need one more foldlevel
    let nparts = 0
    for part in g:LatexBox_fold_parts
        let i = 1
        while i < line("$")
            if getline(i) =~ '^\s*\\' . part . '\>'
                let nparts += 1
                break
            endif
            let i += 1
        endwhile
        if nparts > 1
            let level = 2
            break
        endif
    endfor

    " Combine sections and levels, but ignore unused section commands:  If we
    " don't use the part command, then chapter should have the highest
    " level.  If we don't use the chapter command, then section should be the
    " highest level.  And so on.
    let ignore = 1
    for part in g:LatexBox_fold_sections
        " For each part, check if it is used in the file.  We start adding the
        " part patterns to the fold sections array whenever we find one.
        let partpattern = '^\s*\(\\\|% Fake\)' . part . '\>'
        if ignore
            let i = 1
            while i < line("$")
                if getline(i) =~# partpattern
                    call insert(foldsections, [partpattern, level])
                    let level += 1
                    let ignore = 0
                    break
                endif
                let i += 1
            endwhile
        else
            call insert(foldsections, [partpattern, level])
            let level += 1
        endif
    endfor

    return foldsections
endfunction

" }}}
" LatexBox_FoldLevel {{{

" Parse file to dynamically set the sectioning fold levels
let b:LatexBox_FoldSections = s:FoldSectionLevels()

" Optimize by predefine common patterns
let s:foldparts = '^\s*\\\%(' . join(g:LatexBox_fold_parts, '\|') . '\)'
let s:folded = '\(% Fake\|\\\(document\|begin\|end\|'
            \ . 'front\|main\|back\|app\|sub\|section\|chapter\|part\)\)'

" Fold certain selected environments
let s:notbslash = '\%(\\\@<!\%(\\\\\)*\)\@<='
let s:notcomment = '\%(\%(\\\@<!\%(\\\\\)*\)\@<=%.*\)\@<!'
let s:envbeginpattern = s:notcomment . s:notbslash .
            \ '\\begin\s*{\('. join(g:LatexBox_folded_environments, '\|') .'\)}'
let s:envendpattern = s:notcomment . s:notbslash .
            \ '\\end\s*{\('. join(g:LatexBox_folded_environments, '\|') . '\)}'

function! LatexBox_FoldLevel(lnum)
    " Check for normal lines first (optimization)
    let line  = getline(a:lnum)
    if line !~ s:folded
        return "="
    endif

    " Fold preamble
    if g:LatexBox_fold_preamble == 1
        if line =~# '\s*\\documentclass'
            return ">1"
        elseif line =~# '^\s*\\begin\s*{\s*document\s*}'
            return "0"
        endif

        " " Fold preamble parts
        " if g:LatexBox_fold_preamble_parts == 1
        "     if line =~# '% Usepackages'
        "         return ">1"
        "     elseif line =~# '% Environments'
        "         return "0"
        "     endif
        " endif

        " Fold parts (\frontmatter, \mainmatter, \backmatter, and \appendix)
        if line =~# s:foldparts
            return ">1"
        endif

        " Fold chapters and sections
        for [part, level] in b:LatexBox_FoldSections
            if line =~# part
                return ">" . level
            endif
        endfor

        " Fold environments
        if g:LatexBox_fold_envs == 1
            if line =~# s:envbeginpattern
                return "a1"
            elseif line =~# '^\s*\\end{document}'
                " Never fold \end{document}
                return 0
            elseif line =~# s:envendpattern
                return "s1"
            endif
        endif

        " Return foldlevel of previous line
        return "="
    endif
endfunction

" }}}
" LatexBox_FoldText helper functions {{{

function! s:CaptionFrame(line)
    " Test simple variants first
    let caption1 = matchstr(a:line,'\\begin\*\?{.*}{\zs.\+\ze}')
    let caption2 = matchstr(a:line,'\\begin\*\?{.*}\[.*\]{\zs.\+\ze}')
    let caption3 = matchstr(a:line,'\\begin\*\?{.*}{\zs.\+')

    if len(caption1) > 0
        return caption1
    elseif len(caption2) > 0
        return caption2
    " elseif len(caption3) > 0
    "     return caption3
    else
        let i = v:foldstart
        while i <= v:foldend
            if getline(i) =~ '^\s*\\frametitle'
                return matchstr(getline(i),
                            \ '^\s*\(%\)*\( \)*\\frametitle\(\[.*\]\)\?{\zs.\+\ze}')
            elseif getline(i) =~ '^\s*\(%\)*\( \)*\\titlepage'
                return 'Title page'
            elseif getline(i) =~ '^\s*\(%\)*\( \)*\\tableofcontents'
                return 'Table of contents'
            elseif getline(i) =~ '^\s*\(%\)*\( \)*\(.\)*Thank you\s*$'
                return 'Thank you'
            end
            let i += 1
        endwhile

        return "/~/~NO CAPTION~/~/"
    endif
endfunction

" }}}
" LatexBox_FoldText {{{

function! LatexBox_FoldText()
    " Initialize
    let line = getline(v:foldstart)
    let nlines = v:foldend - v:foldstart + 1
    let level = ''
    let title = line

    " Fold level and number of lines{{{

    let fln = v:foldlevel
    if fln == 1
        let th = 'st'
    elseif fln == 2
        let th = 'nd'
    elseif fln == 3
        let th = 'rd'
    elseif fln > 3
        let th = 'th'
    endif

    let level = '+' . repeat('--', v:foldlevel-1) . ' ' . fln . th . ' '
    " let alignlnr = repeat(' ', 10-2*(v:foldlevel)+1)
    " let lineinfo = nlines . ' lines:     '

    "}}}

    " Preamble{{{

    " if line =~ '\s*\\documentclass'
    if line =~ '\\documentclass'
        let title = 'Preamble' . ' | ' . matchstr(line, '\*\?\s*\[\zs.\{-}\ze\]') . ' | ' . matchstr(line, '\*\?\s*{\zs.\{-}\ze}% F{O{L{D')
    elseif line =~ '% Usepackages'
        let title = 'Usepackages'
    elseif line =~ '% Environments'
        let title = 'Environments'
    elseif line =~ '% Newcommands'
        let title = 'Newcommands'
    endif

    "}}}

    "Title{{{

    if line=~ '\\title'
        let shorttitle = matchstr(line, '\*\?\s*\[\zs.\{-}\ze\]')
        let longtitle = matchstr(line, '\*\?\s*{\zs.\{-}\ze}% F{O{L{D')

        " Giving short-title the priority
        if len(shorttitle) > 0
            let primarytitle = shorttitle
        else
            let primarytitle = longtitle
        endif

        " Making title at max 90-character
        if len(primarytitle) > 90
            let title = 'Title - ' . printf('%.087s', primarytitle) . '...'
        else
            let title = 'Title - ' . primarytitle
        endif

    endif

    "}}}

    " Section-environments, frontmatter, appendix etc{{{

    let sections = '\(\(sub\)*section\|part\|chapter\)'
    let secpat1 = '^\s*\\' . sections . '\*\?\s*{'
    let secpat2 = '^\s*\\' . sections . '\*\?\s*\['
    if line =~ '\\frontmatter'
        let title = "Frontmatter"
    elseif line =~ '\\mainmatter'
        let title = "Mainmatter"
    elseif line =~ '\\backmatter'
        let title = "Backmatter"
    elseif line =~ '\\appendix'
        let title = "Appendix"

    elseif line =~ secpat1 . '.*}% F{O{L{D'
        " Capturing the type of section-environment ((sub*)part|chapter|section)
        let type = matchstr(line, '\*\?\s*\\\zs.\{-}\ze{')
        " Checking whether label exists
        let labelcheck = matchstr(line, '\*\?\s*}\\\zs.\{-}\ze{')

        " Creating different section-environment title depending on whether label exists
        if labelcheck == 'label'
            " Capturing actual label name
            let labelname = matchstr(line, '\*\?\s*}\\label{\zs.\{-}\ze}% F{O{L{D')
            " Capturing section-environment title
            let primarytitle1 = matchstr(line, secpat1 . '\zs.\{-}\ze}\')

            " Making section-environment-title at max 90-character
            if len(primarytitle1) > 90
                let secondarytitle = printf('%.087s', primarytitle1) . '...'
            else
                let aligntitle1 = repeat(' ', 090-len(primarytitle1))
                let secondarytitle = primarytitle1 . aligntitle1
            endif

        else
            " Label doesn't exist
            let label = '    \'
            " Capturing section-environment title
            let primarytitle2 = matchstr(line, secpat1 . '\zs.\{-}\ze}% F{O{L{D')

            " Making section-environment-title at max 90-character
            if len(primarytitle2) > 90
                let secondarytitle = printf('%.087s', primarytitle2) . '...'
            else
                let aligntitle2 = repeat(' ', 090-len(primarytitle2))
                let secondarytitle = primarytitle2 . aligntitle2
            endif
        endif

        " Making label at max 25-character
        if len(labelname) > 25
            let label = '    \label{' . printf('%.022s', labelname) . '...}'
        else
            let label = '    \label{' . labelname . '}'
        endif

        " Final section-environment title
        if type == 'part'
            let title = 'P    ' . secondarytitle . label
        elseif type == 'chapter'
            let title = 'C    ' . secondarytitle . label
        elseif type == 'section'
            let title = 'S    ' . secondarytitle . label
        elseif type == 'subsection'
            let title = 'Ss   ' . secondarytitle . label
        elseif type == 'subsubsection'
            let title = 'Sss  ' . secondarytitle . label
        elseif type == 'chapter*'
            let title = 'C*   ' . secondarytitle . label
        elseif type == 'section*'
            let title = 'S*   ' . secondarytitle . label
        elseif type == 'subsection*'
            let title = 'Ss*  ' . secondarytitle . label
        elseif type == 'subsubsection*'
            let title = 'Sss* ' . secondarytitle . label
        else
            let title = '~    ' . secondarytitle . label
        endif

        "}}}

    " Other types of section patterns{{{

    elseif line =~ secpat1
        let primarytitle = matchstr(line, secpat1 . '\zs.*')
        let aligntitle = repeat(' ', 090-len(primarytitle))
        let label = '    \' . matchstr(line, '\*\?\s*}\\\zs.\{-}\ze% F{O{L{D')
        let title = primarytitle . aligntitle . label
        " let title = matchstr(line, secpat1 . '\zs.*') . '  |  \' . matchstr(line, '\*\?\s*}\\\zs.\{-}\ze% F{O{L{D')
    elseif line =~ secpat2 . '.*\]'
        let primarytitle = matchstr(line, secpat2 . '\zs.\{-}\ze}\')
        let aligntitle = repeat(' ', 090-len(primarytitle))
        let label = '    \' . matchstr(line, '\*\?\s*}\\\zs.\{-}\ze% F{O{L{D')
        let title = primarytitle . aligntitle . label
        " let title = matchstr(line, secpat2 . '\zs.\{-}\ze}\') . '  |  \' . matchstr(line, '\*\?\s*}\\\zs.\{-}\ze% F{O{L{D')
    elseif line =~ secpat2
        let primarytitle = matchstr(line, secpat2 . '\zs.*')
        let aligntitle = repeat(' ', 090-len(primarytitle))
        let label = '    \' . matchstr(line, '\*\?\s*}\\\zs.\{-}\ze% F{O{L{D')
        let title = primarytitle . aligntitle . label
        " let title = matchstr(line, secpat2 . '\zs.*') . '  |  \' . matchstr(line, '\*\?\s*}\\\zs.\{-}\ze% F{O{L{D')
    elseif line =~ 'Fake' . sections . ':'
        let title =  matchstr(line,'Fake' . sections . ':\s*\zs.*')
    elseif line =~ 'Fake' . sections
        let title =  matchstr(line, 'Fake' . sections)
    endif

    "}}}

    " Environments{{{

    " Getting environment title{{{
    if line =~ '\\begin'
        " Capture environment name
        let env = matchstr(line,'\\begin\*\?{\zs\w*\*\?\ze}')
        " Capturing given name to the environment
        let envname = matchstr(line, '\*\?\s*\[\zs.\{-}\ze\]')
        " Checking whether label exists when environment might have a given name
        let labelcheck1 = matchstr(line, '\*\?\s*}\\\zs.\{-}\ze{')
        let labelcheck2 = matchstr(line, '\*\?\s*\]\\\zs.\{-}\ze{')

        " Creating different environment title depending on whether it has a given name
        if labelcheck1 == 'label'
            " No given name to environment, so just capture label and make it environment-title
            let primarytitle = '  ' . matchstr(line, '\*\?\s*}\zs.\{-}\ze% F{O{L{D')

            " Making environment-title at max 120-character
            if len(primarytitle) > 120
                let secondarytitle = printf('%.117s', primarytitle) . '...'
            else
                let secondarytitle = primarytitle
            endif

        elseif labelcheck2 == 'label'
            if envname == ''
                let primarytitle1 = ''
            else
                " Environment has a given name, so capturing it
                let primarytitle1 = ' - ' . envname
            endif

            " Capturing label
            let label1 = matchstr(line, '\*\?\s*\]\zs.\{-}\ze% F{O{L{D')

            " Environment-title should be at max 120-character
            " Making environment-given-name at max 68-character
            if len(primarytitle1) > 68
                let primarytitle2 = printf('%.65s', primarytitle1) . '...'
            else
                let primarytitle2 = primarytitle1
            endif

            " Making label at max 50-character
            if len(label1) > 50
                let label2 = printf('%.46s', label1) . '...}'
            else
                let label2 = label1
            endif

            " Creating environment-title
            let secondarytitle = primarytitle2 . '  ' . label2

        elseif envname == ''
            let secondarytitle = ''
        else
            let secondarytitle = ' - ' . envname
        endif

    "}}}

        " Abstract{{{

        if env == 'abstract'
            let title = 'Abstract'

        "}}}

        " Definition{{{

        elseif env == 'definition'
            let title = 'Definition' . secondarytitle

        elseif env == 'udefinition'
            let title = 'UnnumberedDefinition' . secondarytitle

        elseif env == 'definition*'
            let title = 'UnnumberedDefinition' . secondarytitle

        "}}}

        " Notation{{{

        elseif env == 'notation'
            let title = 'Notation' . secondarytitle

        elseif env == 'unotation'
            let title = 'UnnumberedNotation' . secondarytitle

        elseif env == 'notation*'
            let title = 'UnnumberedNotation' . secondarytitle

        "}}}

        " Lemma{{{

        elseif env == 'lemma'
            let title = 'Lemma' . secondarytitle

        elseif env == 'ulemma'
            let title = 'UnnumberedLemma' . secondarytitle

        elseif env == 'lemma*'
            let title = 'UnnumberedLemma' . secondarytitle

        "}}}

        " Proposition{{{

        elseif env == 'proposition'
            let title = 'Proposition' . secondarytitle

        elseif env == 'uproposition'
            let title = 'UnnumberedProposition' . secondarytitle

        elseif env == 'proposition*'
            let title = 'UnnumberedProposition' . secondarytitle

        "}}}

        " Theorem{{{

        elseif env == 'theorem'
            let title = 'Theorem' . secondarytitle

        elseif env == 'utheorem'
            let title = 'UnnumberedTheorem' . secondarytitle

        elseif env == 'theorem*'
            let title = 'UnnumberedTheorem' . secondarytitle

        "}}}

        " Corollary{{{

        elseif env == 'corollary'
            let title = 'Corollary' . secondarytitle

        elseif env == 'ucorollary'
            let title = 'UnnumberedCorollary' . secondarytitle

        elseif env == 'corollary*'
            let title = 'UnnumberedCorollary' . secondarytitle

        "}}}

        " Proof{{{

        elseif env == 'proof'
            let title = 'Proof'

        "}}}

        " Remark{{{

        elseif env == 'remark'
            let title = 'Remark' . secondarytitle

        elseif env == 'uremark'
            let title = 'UnnumberedRemark' . secondarytitle

        elseif env == 'remark*'
            let title = 'UnnumberedRemark' . secondarytitle

        "}}}

        " Conjecture{{{

        elseif env == 'conjecture'
            let title = 'Conjecture' . secondarytitle

        elseif env == 'uconjecture'
            let title = 'UnnumberedConjecture' . secondarytitle

        elseif env == 'conjecture*'
            let title = 'UnnumberedConjecture' . secondarytitle

        "}}}

        " Frame{{{

        elseif env == 'frame'
            let caption = s:CaptionFrame(line)
            if line =~ '^\s*\\begin'
                " let title = 'Frame - ' . substitute(caption, '}\s*$', '','')
                let title = 'Frame - ' . caption
            elseif line =~ '^\s*% \\begin'
                let title = '[Commented Frame] - ' . caption
            endif

        "}}}

        " Other environments{{{
        else
            " Capture the whole line for other environments
            let primarytitle = matchstr(line, '^\s*\zs.\{-}\ze% F{O{L{D')

            " Making environment-title at max 120-character
            if len(primarytitle) > 120
                let title = printf('%.117s', primarytitle) . '...'
            else
                let title = primarytitle
            endif
        endif

        "}}}

        " Others{{{

        " elseif env == 'lemma'
        "     let title = '\' . matchstr(line, '\*\?\s*\\\zs.\{-}\ze% F{O{L{D')
        "     let title = matchstr(line, '^\s*\zs.\{-}\ze% F{O{L{D')
        " elseif env == 'ulemma'
        "     let title = '\' . matchstr(line, '\*\?\s*\\\zs.\{-}\ze% F{O{L{D')
        "     let title = matchstr(line, '^\s*\zs.\{-}\ze% F{O{L{D')
        " elseif env == 'proposition'
        "     let title = '\' . matchstr(line, '\*\?\s*\\\zs.\{-}\ze% F{O{L{D')
        "     let title = matchstr(line, '^\s*\zs.\{-}\ze% F{O{L{D')
        " elseif env == 'uproposition'
        "     let title = '\' . matchstr(line, '\*\?\s*\\\zs.\{-}\ze% F{O{L{D')
        "     let title = matchstr(line, '^\s*\zs.\{-}\ze% F{O{L{D')
        " elseif env == 'theorem'
        "     let title = '\' . matchstr(line, '\*\?\s*\\\zs.\{-}\ze% F{O{L{D')
        "     let title = matchstr(line, '^\s*\zs.\{-}\ze% F{O{L{D')
        " elseif env == 'utheorem'
        "     let title = '\' . matchstr(line, '\*\?\s*\\\zs.\{-}\ze% F{O{L{D')
        "     let title = matchstr(line, '^\s*\zs.\{-}\ze% F{O{L{D')
        " elseif env == 'corollary'
        "     let title = '\' . matchstr(line, '\*\?\s*\\\zs.\{-}\ze% F{O{L{D')
        "     let title = matchstr(line, '^\s*\zs.\{-}\ze% F{O{L{D')
        " elseif env == 'ucorollary'
        "     let title = matchstr(line, '^\s*\zs.\{-}\ze% F{O{L{D')
        "     let title = '\' . matchstr(line, '\*\?\s*\\\zs.\{-}\ze% F{O{L{D')
        " elseif env == 'remark'
        "     let title = '\' . matchstr(line, '\*\?\s*\\\zs.\{-}\ze% F{O{L{D')
        "     let title = matchstr(line, '^\s*\zs.\{-}\ze% F{O{L{D')
        " elseif env == 'uremark'
        "     let title = '\' . matchstr(line, '\*\?\s*\\\zs.\{-}\ze% F{O{L{D')
        "     let title = matchstr(line, '^\s*\zs.\{-}\ze% F{O{L{D')
        " elseif env == 'proof'
        "     let title = 'Proof'
        "     let title = matchstr(line, '\\label\*\?\s*{\zs.\{-}\ze}')

        "}}}

    endif

    "}}}

    " Helper folds{{{
    " Put 'h' after '%' in the commented line to get helper-folds

    if line =~ '^\s*%h '
        " Capture the whole line for helper-folds
        let primarytitle = matchstr(line, '^\s*%h \zs.\{-}\ze% F{O{L{D')

        " Making helper-folds at max 120-character
        if len(primarytitle) > 120
            let title = '[H] - ' . printf('%.121s', primarytitle) . '...'
            " Don't mess up my preamble fold-titles
        " elseif line =~ '% Usepackages'
        "     let title = 'Usepackages'
        " elseif line =~ '% Environments'
        "     let title = 'Environments'
        " elseif line =~ '% Newcommands'
        "     let title = 'Newcommands'
        else
            let title = '[H] - ' . primarytitle
        endif
    endif

    "}}}

    " Commented-folds{{{
    " Put 'c' after '%' in the commented line to get commented-folds

    if line =~ '^\s*%c '
        " Capture the whole line for commented-folds
        let primarytitle = matchstr(line, '^\s*%c \zs.\{-}\ze% F{O{L{D')

        " Making commented-folds at max 120-character
        if len(primarytitle) > 120
            let title = '[Commented] - ' . printf('%.121s', primarytitle) . '...'
        else
            let title = '[Commented] - ' . primarytitle
        endif
    endif

    "}}}

    "" Helper folds{{{

    "if line =~ '^\s*% '
    "    let primarytitle = matchstr(line, '^\s*% \zs.\{-}\ze% F{O{L{D')
    "    if title != 'Usepackages' && title != 'Environments' && title != 'Newcommands'
    "        if len(primarytitle) > 124
    "            let title = '[H]  - ' . printf('%.121s', primarytitle) . '...'
    "        else
    "            let title = '[H]  - ' . primarytitle
    "        endif
    "    endif
    "endif

    ""}}}

    return printf('%-15s %-138s %4d lines', level, title, nlines)
    " return printf('%-15s %-138s', level, title)
    " return printf('%-15s %.095s %-40s %4d lines', level, title, label, nlines)
    " return level . alignlnr . title . ' ' . repeat(' ', 10) . nlines

endfunction

" }}}
