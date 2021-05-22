if exists("g:loaded_user")
    finish
endif
let g:loaded_user = 1

let s:path = expand("~/.vim").."/pack/user/"
let s:packs = {}
let s:config_queue = []
let s:config_done = {}

function! user#setup() abort
    autocmd VimEnter * ++once call user#startup()
endfunction

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

    let l:pack.after = []
    if has_key(a:args, "after")
        if type(a:args.after) == v:t_string
            let l:pack.after = [ a:args.after ]
        else
            let l:pack.after = a:args.after
        end
    endif

    let l:pack.repo = get(a:args, "repo", "https://github.com/"..l:pack.name..".git")

    call s:request(l:pack)
endfunction

function! user#startup() abort
    call s:await_jobs()
    call s:do_config_queue()
endfunction

function! user#update() abort
    for l:pack in values(s:packs)
        let l:pack.hash = s:git_head_hash(l:pack)
        call system("git -C "..fnameescape(l:pack.install_path).." pull")
        """ TODO async jobs
        let l:pack.job = "a fun job"
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
    """ TODO async jobs
    let a:pack.job = "a fun job"

    let a:pack.newly_installed = v:true
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
    call add(s:config_queue, a:pack)
endfunction

function! s:await_jobs() abort
    for l:pack in values(s:packs)
        if has_key(l:pack, "job")
            """ TODO async jobs
            silent! execute "helptags" fnameescape(l:pack.install_path).."/doc"
            let l:pack.job = v:null

            if has_key(l:pack, "newly_installed") && type(l:pack.install) == v:t_func
                call l:pack.install()
            endif

            let l:hash = s:git_head_hash(l:pack)
            if has_key(l:pack, "hash") && l:pack.hash != l:hash
                if type(l:pack.update) == v:t_func
                    call l:pack.update()
                end
                let a:pack.hash = l:hash
            endif
        endif
    endfor
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

function! s:can_config(pack) abort
    for l:after in a:pack.after
        if !has_key(s:config_done, l:after)
            return v:false
        endif
    endfor
    return v:true
endfunction

function! s:do_config_queue() abort
    let l:counter = 0
    while !empty(s:config_queue) && l:counter < len(s:config_queue)
        let l:pack = remove(s:config_queue, 0)
        if s:can_config(l:pack)
            call s:config(l:pack)
            let l:counter = 0
        else
            call add(s:config_queue, l:pack)
            let l:counter = l:counter + 1
        endif
    endwhile
endfunction
