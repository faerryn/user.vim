if exists("g:loaded_user")
    finish
endif
let g:loaded_user = 1

let s:path = expand("~/.vim").."/pack/user/"
let s:packs = {}
let s:config_queue = []
let s:config_done = {}

function! user#use(args) abort
    if type(a:args) == v:t_string
        return user#use({ "name": a:args })
    endif

    if type(a:args) != v:t_dict
        throw "user#user -- invalid args"
    endif

    let l:pack = {}
    let l:pack.name = a:args.name

    let l:pack.repo = get(a:args, "repo", v:null)
    let l:pack.branch = get(a:args, "branch", v:null)

    let l:pack.subdir = get(a:args, "subdir", "")

    let l:pack.init = get(a:args, "init", v:null)
    let l:pack.config = get(a:args, "config", v:null)

    let l:pack.install = get(a:args, "install", v:null)
    let l:pack.update = get(a:args, "update", v:null)

    let l:pack.repo = get(a:args, "repo", "https://github.com/"..l:pack.name..".git")

    call s:request(l:pack)
endfunction

function! user#update() abort
    for l:pack in values(s:packs)
        let l:old_hash = s:git_head_hash(l:pack)
        call system("git -C "..fnameescape(l:pack.install_path).." pull")
        let l:new_hash = s:git_head_hash(l:pack)

        if l:old_hash != l:new_hash && type(l:pack.update) == v:t_func
            call l:pack.update()
        end
    endfor
endfunction

function! s:git_head_hash(pack) abort
    return system("git -C "..fnameescape(a:pack.install_path).." rev-parse HEAD")
endfunction

function! s:install(pack) abort
    if isdirectory(a:pack.install_path)
        return
    end

    let l:command = "git clone --depth 1 --recurse-submodules "
    if type(a:pack.branch) == v:t_string
        let l:command = l:command.."--branch "..fnameescape(a:pack.branch).." "
    endif
    let l:command = l:command..fnameescape(a:pack.repo).." "..fnameescape(a:pack.install_path)

    call system(l:command)
    call s:gen_helptags(a:pack)
    if type(a:pack.install) == v:t_func
        call a:pack.install()
    endif
endfunction

function! s:request(pack) abort
    if has_key(s:packs, a:pack.name)
        throw pack.name.." is requested more than once"
    endif
    let s:packs[a:pack.name] = a:pack

    if type(a:pack.init) == v:t_string
        call a:pack.init()
    endif

    let l:install_path = a:pack.name
    if type(a:pack.branch) == v:t_string
        let l:install_path = l:install_path.."/branch/"..a:pack.branch
    else
        let l:install_path = l:install_path.."/default/default"
    endif
    let l:packadd_path = l:install_path.."/"..a:pack.subdir
    let a:pack.packadd_path = l:packadd_path
    let a:pack.install_path = s:path.."/opt/"..l:install_path

    call s:install(a:pack)
    call s:config(a:pack)
endfunction

function! s:gen_helptags(pack) abort
    silent! execute "helptags" fnameescape(a:pack.install_path).."/doc"
endfunction

function! s:config(pack) abort
    execute "packadd" fnameescape(a:pack.packadd_path)

    if get(v:, "vim_did_enter", v:false)
        for l:after_source in split(glob(a:pack.install_path.."/after/plugin/**/*.vim"), "\n")
            execute "source" fnameescape(l:after_source)
        endfor
    end

    if type(a:pack.config) == v:t_func
        call a:pack.config()
    end

    let s:config_done[a:pack.name] = v:true
endfunction
