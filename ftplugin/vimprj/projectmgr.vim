" File:     projectmgr.vim
"
" License:  Vim License  (see vim's :help license)
"           No warranty, use this program At-Your-Own-Risk.
"
" Purpose:  This vim script acts as a coordinator with vimprj.vim and projectmgr.py.
"           It works with taglist(vim script #273), lookupfile(vim script #1581)
"           supertab(Vim script #1643) and NERD_tree(vim script #1658) to provide
"           an full functional project mgr for a project.
"           To make this plugin work better with large project, I patch against some
"           vim plugins. The patches are packaged in a tarball. You can find it where
"           you find this plugin.
"
" Author:   Liang Feng <fliang98 AT gmail DOT com>
"
" Version:  0.8
"
" Install:  Drop both projectmgr.vim and projectmgr.py into $VIM/vimfiles/ftplugin/vimprj directory.
"
" Usage:    Just need to write a trivial project setting file for one project.
"           The filename suffix MUST be .vimprj. Open project setting file within vim will
"           load project automatically.
"
"           There are three public commands:
"
"           1. Preload
"              Purpose: If vimprj file changed from out side, run this command.
"              Param:   No parameter
"              Notes:   If vimprj file changed inside (g)vim, the project
"                       settings will be reloaded automatically when you save file.
"
"           2. Pupdate
"              Purpose: Update tags, including filename tags(for lookupfile plugin),
"                       ctags, cscope database.
"              Param:   one parameter. Must be: 'all', 'cscope', 'ctags' or 'ftags'.
"                       'cscope': means update cscope database with cscope command.
"                       'ctags' : means update tags with ctags command.
"                       'ftags' : means update filename tags used by lookupfile plugin.
"                       'gtags' : means update gtags with gtags command.
"                       'all'   : means update all of above three.
"              Notes:   You can use tab to choose the parameter.
"
"           3. Pstatus
"              Purpose: Show current project status.
"              Param:   No parameter
"
"           4. Punload
"              Purpose: unload current project from vim
"
"           TODO: write more everyday use cases.
"
" Known Issues: 1. cscope can not handle whitespace in directory or file name,
"                  because of the limitation of stat() function.
"               2. Since gtags can not work properly with vim, so disable it
"                  temporary.
"
" Example:  Below is my project setting file for Linux kernel src codes. You
"           can refer to 'vimprj_template' file to read the fine point.
"
"           [default]
"           project_name = linux-2.6.32
"           project_root_path = /home/dev/linux-2.6.32/
"           filename_finding_pattern = ^((GNU)?Makefile|.+\.(cpp|c|h|cc|cxx|vim|py|ini|xml|cfg|sh|mk|lua))$
"           project_excluding_path = Documentation
"           project_update_interval = 30
"           project_external_ctags_files =

" Prerequisite check {{{

if v:version < 700
    echoerr 'Required vim 7.0 or greater!'
    finish
endif

" TODO: check detailed version
if !has('python')
    echoerr 'Required vim compiled with +python!'
    finish
endif

" End of Prerequisite check }}}

" Function definitions {{{

function! s:Warn(msg) "{{{
    echohl WarningMsg
    echomsg a:msg
    echohl None
endfunction "}}}

function! s:SetupAllGlobalVariables() "{{{
    let g:project_name = ''
    let g:project_root_path = ''
    let g:project_settingfile_name = ''
    let g:project_settingfile_path = ''
    let g:filename_finding_pattern = ''
    let g:project_excluding_path = ''
    let g:project_update_interval = ''
    let g:project_external_ctags_files = ''
    let g:ctags_name = ''
    let g:lookupfiletags_name = ''
    let g:cscope_name = ''
    let g:gtags_name = ''
    " This variable is defined in lookupfile plugin (Vim script #1581)
    let g:LookupFile_TagExpr = ''
    if !exists('g:cscope_sort_path')
        let g:cscope_sort_path = "D:/GnuWin32/bin"
    endif
    let g:last_update_time = ''
    let g:need_stop_schedule_thread = 0
endfunction " }}}

function! s:CleanupAllGlobalVariables() "{{{
    unlet! g:project_name
    unlet! g:project_root_path
    unlet! g:project_settingfile_name
    unlet! g:project_settingfile_path
    unlet! g:project_excluding_path
    unlet! g:project_update_interval
    unlet! g:project_excluding_path
    unlet! g:ctags_name
    unlet! g:lookupfiletags_name
    unlet! g:cscope_name
    unlet! g:gtags_name
    unlet! g:cscope_sort_path
    let g:LookupFile_TagExpr = ''
    unlet! g:last_update_time
    unlet! g:need_stop_schedule_thread
endfunction "}}}

function! s:LoadProjectSettings() "{{{
    call s:SetupAllGlobalVariables()

python << EOFPYTHON
from projectmgr import prjmgr
prjmgr.load_project_settings()
EOFPYTHON

    exec "set tags+=" . fnameescape(g:ctags_name)
    for t in split(g:project_external_ctags_files, ',')
        " trim spaces
        exec "set tags+=" . fnameescape(substitute(t, '^\s\+\|\s\+$', "", "g"))
    endfor
    cscope kill -1
    exec "cscope add " . fnameescape(g:cscope_name)
endfunction "}}}

function! s:UpdateLookupFileTags() "{{{
python << EOFPYTHON
from projectmgr import prjmgr
prjmgr.update_lookupfiletags()
EOFPYTHON
endfunction " }}}

function! s:UpdateCtags() "{{{
python << EOFPYTHON
from projectmgr import prjmgr
prjmgr.update_ctags()
EOFPYTHON
endfunction " }}}

function! s:UpdateCscope() "{{{
python << EOFPYTHON
from projectmgr import prjmgr
prjmgr.update_cscope()
EOFPYTHON
endfunction " }}}

function! s:UpdateGtags() "{{{
python << EOFPYTHON
from projectmgr import prjmgr
prjmgr.update_gtags()
EOFPYTHON
endfunction " }}}

function! s:UpdateProjectTags() "{{{
python << EOFPYTHON
from projectmgr import prjmgr
prjmgr.update_projecttags()
EOFPYTHON
endfunction " }}}

function! s:ScheduleUpdateProjectTags() "{{{
python << EOFPYTHON
from projectmgr import prjmgr
prjmgr.schedule_update_projecttags()
EOFPYTHON
endfunction " }}}

function! s:SetupCscopeEnv() "{{{
    " Disable gtags temporary
    " set cscopeprg=gtags-cscope
    set nocsverb
    set cscopetagorder=1
    set cscopetag
    set cscopepathcomp=0
endfunction "}}}

function! s:CleanupCscopeEnv() "{{{
endfunction "}}}

function! s:SetupGtagsEnv() "{{{
    " Treat 'h' file as c++ type for gtags
    let $GTAGSFORCECPP = 1
    " Set the root of source tree for gtags
    let $GTAGSROOT = g:project_root_path
    " Set the directory on which tag files exists
    let $GTAGSDBPATH = expand("%:p:h")
endfunction "}}}

function! s:CleanupGtagsEnv() "{{{
    set cscopeprg&
    let $GTAGSFORCECPP=""
    let $GTAGSROOT=""
    let $GTAGSDBPATH=""
endfunction "}}}

function! s:SetupAutoCommands() "{{{
    augroup projectmgr
        au!
        au BufEnter * let &titlestring = '%<[%{g:project_name}] Project - (%F)'
        au BufWritePost *.vimprj call s:ReloadProject()
        au VimLeave * call s:UnloadProject()
    augroup END
endfunction "}}}

function! s:CleanupAutoCommands() "{{{
    augroup projectmgr
        au!
    augroup END
    aug! projectmgr
    set titlestring&
endfunction "}}}

function! s:SetupPublicMappings() "{{{
    " Go to global definition
    " :help g_CTRL-]
    nnoremap <silent> <unique> <Leader>gg g<C-]>
    " Find caller
    nnoremap <silent> <unique> <Leader>gc :cscope find c <C-R>=expand('<cword>')<CR><CR>
    " Find file which includes the file whose name under cursor.
    nnoremap <silent> <unique> <Leader>gi :cscope find i <C-R>=expand('<cfile>')<CR><CR>

    " Remap gf and gF to leverage the lookupfile plugin.
    " always open in new tab
    nnoremap <silent> gf :exec ':LUTags ' . fnamemodify(expand('<cfile>'), ':t')<CR>
    nnoremap <silent> gF :exec ':LUTags ' . fnamemodify(expand('<cfile>'), ':t')<CR>
    " :help CTRL-W_gf
    " :help CTRL-W_gF
    nnoremap <silent> <C-W>gf :exec ':LUTags ' . fnamemodify(expand('<cfile>'), ':t')<CR>
    nnoremap <silent> <C-W>gF :exec ':LUTags ' . fnamemodify(expand('<cfile>'), ':t')<CR>
endfunction "}}}

function! s:CleanupPublicMappings() "{{{
    nunmap <Leader>gg
    nunmap <Leader>gc
    nunmap <Leader>gi
    nunmap gf
    nunmap gF
    nunmap <C-W>gf
    nunmap <C-W>gF
endfunction "}}}

function! s:ConfirmedUnloadProject() "{{{
    let l:prompt = 'Unload current project? [' . g:project_settingfile_name . ']'
    let l:choice = confirm(l:prompt, "&Yes\n&No\n", 2)
    if l:choice == 1
        exec 'bwipeout ' . g:project_settingfile_name
        call s:UnloadProject()
    endif
endfunction "}}}

function! s:SetupPublicCommands() "{{{
    command Preload call s:ReloadProject()
    command -nargs=1 -complete=custom,s:GetTagTypeList Pupdate call s:UpdateProject(<f-args>)
    command Pstatus call s:ProjectStatus()
    command Punload call s:ConfirmedUnloadProject()
endfunction "}}}

function! s:CleanupPublicCommands() "{{{
    delcommand Preload
    delcommand Pupdate
    delcommand Pstatus
    delcommand Punload
endfunction "}}}

function! s:LoadProject() "{{{
    try
        call s:LoadProjectSettings()
        call s:SetupCscopeEnv()
        call s:SetupGtagsEnv()

        call s:SetupAutoCommands()
        call s:SetupPublicMappings()
        call s:SetupPublicCommands()

        call s:ScheduleUpdateProjectTags()
        let g:SuperTabCompletionContexts = ['HeaderFileContextText']
                                           \ + g:SuperTabCompletionContexts
        exec 'cd ' . g:project_root_path

    catch /.*/
        call s:Warn(v:exception)
        call s:Warn("ProjectMgr Error: LoadProject Failed!")
    endtry
endfunction " }}}

function! s:UnloadProject() "{{{
    if exists('g:need_stop_schedule_thread') && g:need_stop_schedule_thread == 0
        let g:need_stop_schedule_thread = 1
python << EOFPYTHON
from projectmgr import prjmgr
prjmgr.stop_event.set()
prjmgr.scheduleupdate_thread.join()
EOFPYTHON
        exec "set tags-=" . fnameescape(g:ctags_name)
        for t in split(g:project_external_ctags_files, ',')
            " trim spaces
            exec "set tags-=" . fnameescape(substitute(t, '^\s\+\|\s\+$', "", "g"))
        endfor
        cscope kill -1
        call s:CleanupAutoCommands()
        call s:CleanupPublicMappings()
        call s:CleanupGtagsEnv()
        call s:CleanupCscopeEnv()
        call s:CleanupPublicCommands()
        call s:CleanupAllGlobalVariables()
    endif
endfunction "}}}

function! s:ReloadProject() "{{{
    call s:UnloadProject()
    call s:LoadProject()
endfunction "}}}

function! s:GetTagTypeList(ArgLead,CmdLine,CursorPos) "{{{
    let l:tagtype_list = "all\n"
    let l:tagtype_list .= "cscope\n"
    let l:tagtype_list .= "ctags\n"
    let l:tagtype_list .= "ftags\n"
    let l:tagtype_list .= "gtags\n"
    return l:tagtype_list
endfunction " }}}

function! s:UpdateProject(tag_type) "{{{
    try
        if a:tag_type == 'all'
            call s:UpdateProjectTags()
        elseif a:tag_type == 'cscope'
            call s:UpdateCscope()
        elseif a:tag_type == 'ctags'
            call s:UpdateCtags()
        elseif a:tag_type == 'ftags'
            call s:UpdateLookupFileTags()
        elseif a:tag_type == 'gtags'
            call s:UpdateGtags()
        endif
    catch /.*/
        call s:Warn(v:exception)
        call s:Warn("ProjectMgr Error: UpdateProject Failed!")
    endtry
endfunction " }}}

function! s:ProjectStatus() "{{{
    echo 'name:' g:project_name
    echo 'root path:' g:project_root_path
    echo 'filename finding pattern:' g:filename_finding_pattern
    echo 'excluding path:' g:project_excluding_path
    echo 'update interval:' g:project_update_interval
    echo 'filename tag file:' g:LookupFile_TagExpr
    echo 'ctags files:' &tags
    echo 'external ctags files:' g:project_external_ctags_files
    echo 'gtags files:' g:gtags_name
    echo 'connected cscope database:' cscope_connection() ? g:cscope_name : "None"
    echo 'last update time:' g:last_update_time
endfunction "}}}

function! s:CmpByName(f1, f2) "{{{
    let lhs = a:f1["abbr"]
    let rhs = a:f2["abbr"]
    return lhs == rhs ? 0 : lhs > rhs ? 1 : -1
endfunction " }}}

function! HeaderFileComplete(findstart, base) "{{{
    if a:findstart
        let line = getline('.')
        let start = col('.') - 1
        while start > 0 && line[start - 1] !~ '[ \t"</\\]'
            let start -= 1
        endwhile
        return start
    else
        if strlen(a:base) < 2
            let status_msg = "Type at least 2 characters"
            let msg_line = [{'word': a:base, 'abbr': status_msg}]
            return msg_line
        endif
        let pattern = '^' . a:base . '.*\.\(h\|H\|hpp\)$'
        let _tags = &tags
        try
            let &tags = eval(g:LookupFile_TagExpr)
            let taglist = taglist(pattern)
        catch /.*/
            echohl ErrorMsg | echo "Exception: " . v:exception | echohl NONE
            return ''
        finally
            let &tags = _tags
        endtry

        " Show the matches for what is typed so far.
        let headerfiles = map(taglist, '{'.
                    \ '"word": fnamemodify(v:val["filename"], ":t"), '.
                    \ '"abbr": v:val["name"], '.
                    \ '"menu": fnamemodify(v:val["filename"], ":h"), '.
                    \ '"dup": 1, '.
                    \ '}')
        if type(get(headerfiles, 0)) == 4
            call sort(headerfiles, "s:CmpByName")
        else
            call sort(headerfiles)
        endif
        return headerfiles
    endif
endfunction " }}}

function! HeaderFileContextText() "{{{
    let curline = getline('.')
    let cnum = col('.')
    if curline =~ &include . '\s*\("\|<\s*\)\(\w\|-\|\.\|_\|\\\|/\)*\%' . cnum . 'c'
        let g:supertab_completefunc_bak = &completefunc
        set completefunc=HeaderFileComplete
        let g:completeopt_bak = &completeopt
        if g:completeopt_bak !~ 'menuone'
            set completeopt+=menuone
        endif
        au! InsertLeave *
                    \ if exists('g:supertab_completefunc_bak') |
                    \   let &completefunc = g:supertab_completefunc_bak |
                    \   unlet g:supertab_completefunc_bak |
                    \   let &completeopt = g:completeopt_bak |
                    \   unlet g:completeopt_bak |
                    \ endif
        return "\<c-x>\<c-u>"
    endif
endfunction " }}}

" End of function definition }}}

function s:Startup() "{{{
    if exists('g:loaded_projectmgr_plugin')
        let l:new_project = expand("%:p")

        if s:current_project ==# l:new_project
            call s:ReloadProject()
        else
            let l:prompt = 'Load new project? [' . fnamemodify(l:new_project, ':t'). ']'
            let l:choice = confirm(l:prompt, "&Yes\n&No\n", 2)
            if l:choice == 1
                exec 'bwipeout ' . fnameescape(s:current_project)
                let s:current_project = l:new_project
                call s:ReloadProject()
            endif
        endif
        finish
    else
        " first time run
        call s:LoadProject()
    endif
    let g:loaded_projectmgr_plugin = 1
    let s:current_project = expand("%:p")
endfunction "}}}

" Initialization {{{
call s:Startup()
" End of Initialization }}}


" vim: set et sw=4 ts=4 ff=unix fdm=marker :
