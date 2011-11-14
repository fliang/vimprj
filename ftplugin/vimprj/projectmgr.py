#! /usr/bin/env python
# -*- coding: utf-8 -*-

# @License:  Vim License  (see vim's :help license)
#            No warranty, use this program At-Your-Own-Risk.

# @Author:   Liang Feng (fliang98 AT gmail DOT com)
# @Version:  0.8

from __future__ import with_statement
import vim
import os
import threading
import subprocess

def _error_handler(f):
    def new_f(self):
        try:
            f(self)
        except BaseException, e:
            errmsg = 'ProjectMgr Error: Function \'%s\'-> %s' % (f.__name__, e)
            vim.command('throw "%s"' % errmsg)
    return new_f

# @brief:  one-shot update thread class
class _UpdateThread(threading.Thread):
    def __init__(self, *update_funs):
        threading.Thread.__init__(self)
        self.__update_funs = update_funs

    def run(self):
        for f in self.__update_funs:
            f()

# @brief:  scheduled update thread class
class _ScheduleUpdateThread(threading.Thread):
    def __init__(self, stop_event, *update_funs):
        threading.Thread.__init__(self)
        self.stop_event = stop_event
        self.__update_funs = update_funs

    def run(self):
        while vim.eval('g:need_stop_schedule_thread') != 1:
            # verify project_update_interval
            # set project_update_interval to proper value, if its value is too low.
            interval = vim.eval('g:project_update_interval')
            if interval != '':
                project_update_interval = int(interval)
                if project_update_interval <= 0:
                    # stop scheduled update thread.
                    return
                elif project_update_interval < 5:
                    project_update_interval = 5
            else:
                # do not get the interval value, stop scheduled update thread.
                return
            self.stop_event.wait(project_update_interval * 60)
            if vim.eval('g:need_stop_schedule_thread') == '1':
                return
            for f in self.__update_funs:
                f()
                if vim.eval('g:need_stop_schedule_thread') == '1':
                    return

# @brief:  project mgr class
class _ProjectMgr(object):
    def __init__(self):
        # Instance data member
        self.__ctags_update_lock = threading.Lock()
        self.__ftags_update_lock = threading.Lock()
        self.__cscope_update_lock = threading.Lock()
        self.__gtags_update_lock = threading.Lock()

    # Public method
    @_error_handler
    def load_project_settings(self):
        import ConfigParser
        import StringIO
        cb = vim.current.buffer

        s = StringIO.StringIO("\n".join(cb[0 : len(cb)]))
        config = ConfigParser.ConfigParser()
        config.readfp(s)

        project_name = config.get('default', 'project_name')
        vim.command("let g:project_name = '%s'" % project_name)

        vim.command("let g:project_root_path = '%s'" \
                    % config.get('default', 'project_root_path'))
        vim.command("let g:filename_finding_pattern = '%s'" \
                    % config.get('default', 'filename_finding_pattern'))
        vim.command("let g:project_excluding_path = '%s'" \
                    % config.get('default', 'project_excluding_path'))
        vim.command("let g:project_update_interval = '%s'" \
                    % config.get('default', 'project_update_interval'))
        project_external_ctags_files = config.get('default', 'project_external_ctags_files')
        vim.command("let g:project_external_ctags_files = '%s'"  % project_external_ctags_files)

        project_settingfile_name = cb.name
        vim.command("let g:project_settingfile_name = '%s'" % project_settingfile_name)
        project_settingfile_path = os.path.dirname(project_settingfile_name)
        vim.command("let g:project_settingfile_path = '%s'" % project_settingfile_path)

        ctags_name = os.path.join(project_settingfile_path, project_name + ".ctags")
        vim.command("let g:ctags_name = '%s'" % ctags_name)

        lookupfiletags_name = os.path.join(project_settingfile_path, project_name + ".ftags")
        vim.command("let g:lookupfiletags_name = '%s'" % lookupfiletags_name)

        cscope_name = os.path.join(project_settingfile_path, project_name + ".out")
        vim.command("let g:cscope_name = '%s'" % cscope_name)

        # Add string function to lookuofiletags_name to make lookupfile plugin happy
        # User raw string to escape space to make vim options happy
        vim.command("let g:LookupFile_TagExpr = string('%s')" \
                    % lookupfiletags_name.replace(' ', r'\\ '))

    @_error_handler
    def update_lookupfiletags(self):
        update_thread = _UpdateThread(self.__update_lookupfiletags)
        update_thread.daemon = True
        update_thread.start()

    @_error_handler
    def update_ctags(self):
        update_thread = _UpdateThread(self.__update_ctags)
        update_thread.daemon = True
        update_thread.start()

    @_error_handler
    def update_cscope(self):
        update_thread = _UpdateThread(self.__update_cscope)
        update_thread.daemon = True
        update_thread.start()

    @_error_handler
    def update_gtags(self):
        update_thread = _UpdateThread(self.__update_gtags)
        update_thread.daemon = True
        update_thread.start()

    @_error_handler
    def update_projecttags(self):
        update_thread = _UpdateThread(self.__update_lookupfiletags, \
                                      self.__update_ctags, \
                                      self.__update_cscope)
        update_thread.daemon = True
        update_thread.start()

    @_error_handler
    def schedule_update_projecttags(self):
        self.stop_event = threading.Event()
        self.scheduleupdate_thread = _ScheduleUpdateThread(self.stop_event, \
                                                           self.__update_lookupfiletags, \
                                                           self.__update_ctags, \
                                                           self.__update_cscope)
        self.scheduleupdate_thread.daemon = True;
        self.scheduleupdate_thread.start()

    # Private method
    def __update_lookupfiletags(self):
        with self.__ftags_update_lock:
            files_fullpath_list = self.__generate_fullpath_list()

            name_dir_list = ["!_TAG_FILE_SORTED\t2\t/2=foldcase/"]
            name_dir_list.extend(sorted([os.path.basename(x) + '\t' + x + '\t' + '1'\
                                 for x in files_fullpath_list], key=str.lower))

            lookupfiletags_name = vim.eval('g:lookupfiletags_name')
            lookupfiletags_tmpname = lookupfiletags_name + ".tmp"
            with open(lookupfiletags_tmpname, 'w') as f:
                f.write('\n'.join(name_dir_list))

            vim.command("call rename('%s', '%s')"
                        % (lookupfiletags_tmpname, lookupfiletags_name))

            # Add string function to lookuofiletags_name to make lookupfile plugin happy
            # User raw string to escape space to make vim options happy
            vim.command("let g:LookupFile_TagExpr = string('%s')" \
                        % lookupfiletags_name.replace(' ', r'\\ '))
            vim.command("let g:last_update_time = strftime('%Y-%m-%d %H:%M:%S', localtime())")
            vim.command("echo 'Updating filename tags ... DONE (%d files)'" % len(files_fullpath_list))

    def __update_ctags(self):
        with self.__ctags_update_lock:
            project_root_path = vim.eval('g:project_root_path')

            project_excluding_path = ''
            for p in vim.eval('g:project_excluding_path').split(','):
                project_excluding_path += '--exclude=%s ' % p

            ctags_name = vim.eval('g:ctags_name')
            ctags_tmpname = ctags_name + '.tmp'

            update_ctags_cmd = []
            update_ctags_cmd.append('ctags')
            update_ctags_cmd.append('"--langmap=make:+([Mm]akefile.*)"')
            # Since ctags Windows version do not support wildcards for '--langmap',
            # add special cases below. You can add yours below.
            # Refer to ctags manual for fine points.
            update_ctags_cmd.append('"--langmap=make:+.mk"')
            update_ctags_cmd.append('"--langmap=make:+.mak"')
            update_ctags_cmd.append('"--langmap=make:+(Makefile)"')
            update_ctags_cmd.append('"--langmap=make:+(makefile)"')
            update_ctags_cmd.append('"--langmap=make:+(GNUmakefile)"')
            # End specical case

            # Avoid ctags-5.8 crash with .ml mapped to lisp.
            update_ctags_cmd.append('"--langmap=lisp:+.ml"')
            update_ctags_cmd.append('-R')
            update_ctags_cmd.append('--sort=yes')
            update_ctags_cmd.append('--c++-kinds=+p')
            update_ctags_cmd.append('--fields=+iaS')
            update_ctags_cmd.append('--extra=+q')
            update_ctags_cmd.append('"%s"' % project_excluding_path)
            update_ctags_cmd.append('-f "%s"' % ctags_tmpname)
            update_ctags_cmd.append('"%s"' % project_root_path)

            # On Linux, before the command is done, switch to shell by ':shell'.
            # When done, the 'No child processes' exception will be thrown out.
            # Just ignore it. It seems that it's a Python's bug.
            try:
                # On Windows, to hide dos prompt window, use the following command.
                subprocess.Popen(' '.join(update_ctags_cmd),
                                 shell=True,
                                 stdout=subprocess.PIPE).communicate()[0]
            except OSError:
                pass

            vim.command("call rename('%s', '%s')" % (ctags_tmpname, ctags_name))
            vim.command("let g:last_update_time = strftime('%Y-%m-%d %H:%M:%S', localtime())")
            vim.command("echo 'Updating ctags ... DONE'")

    def __update_cscope(self):
        with self.__cscope_update_lock:

            files_fullpath_list = self.__generate_fullpath_list()
            files_fullpath_list = [f.replace('\\', '/') for f in files_fullpath_list]
            files_fullpath_list = [f.replace('"', r'\"') for f in files_fullpath_list]
            files_fullpath_list = ['"' + f + '"' for f in files_fullpath_list]

            cscope_name = vim.eval('g:cscope_name')
            cscope_tmpname = cscope_name + ".tmp"

            update_cscope_cmd = []
            update_cscope_cmd.append('cscope')
            update_cscope_cmd.append('-bckq')
            update_cscope_cmd.append('-i -')
            update_cscope_cmd.append('-f "%s"' % cscope_tmpname.replace('\\', '/'))

            if os.name == 'nt':
                _cwd = vim.eval('g:cscope_sort_path')
            else:
                _cwd = '/tmp'

            # On Linux, before the command is done, switch to shell by ':shell'.
            # When done, the 'No child processes' exception will be thrown out.
            # Just ignore it. It seems that it's a Python's bug.
            try:
                # On Windows, to hide dos prompt window, use the following command.
                subprocess.Popen(' '.join(update_cscope_cmd),
                                 shell=True,
                                 cwd=_cwd,
                                 stdin=subprocess.PIPE,
                                 stdout=subprocess.PIPE).communicate('\n'.join(files_fullpath_list))[0]
            except OSError:
                pass

            vim.command("cscope kill -1")
            vim.command("call rename('%s', '%s')" % (cscope_tmpname, cscope_name))
            vim.command("call rename('%s.in', '%s.in')" % (cscope_tmpname, cscope_name))
            vim.command("call rename('%s.po', '%s.po')" % (cscope_tmpname, cscope_name))
            vim.command("cscope add %s" % cscope_name.replace('\\', '/'))
            vim.command("let g:last_update_time = strftime('%Y-%m-%d %H:%M:%S', localtime())")
            vim.command("echo 'Updating cscope database ... DONE'")

    def _update_gtags(self):
        with self.__gtags_update_lock:

            files_fullpath_list = self.__generate_fullpath_list()
            files_fullpath_list = [f.replace('\\', '/') for f in files_fullpath_list]
            files_fullpath_list = [f.replace('"', r'\"') for f in files_fullpath_list]

            update_gtags_cmd = []
            update_gtags_cmd.append('gtags')
            update_gtags_cmd.append('-f -')
            update_gtags_cmd.append(vim.eval('g:project_settingfile_path'))

            # On Linux, before the command is done, switch to shell by ':shell'.
            # When done, the 'No child processes' exception will be thrown out.
            # Just ignore it. It seems that it's a Python's bug.
            try:
                # On Windows, to hide dos prompt window, use the following command.
                subprocess.Popen(' '.join(update_gtags_cmd),
                                 shell=True,
                                 stdin=subprocess.PIPE,
                                 stdout=subprocess.PIPE).communicate('\n'.join(files_fullpath_list))[0]
            except OSError:
                pass
            vim.command("let g:last_update_time = strftime('%Y-%m-%d %H:%M:%S', localtime())")
            vim.command("echo 'Updating gtags ... DONE'")

    def __generate_fullpath_list(self):
            import re
            files_fullpath_list = []
            project_root_path = vim.eval('g:project_root_path')
            filename_finding_pattern = r'%s' % vim.eval('g:filename_finding_pattern')
            # ignore case
            p = re.compile(filename_finding_pattern, re.I)
            project_excluding_path = vim.eval('g:project_excluding_path').split(',')
            project_excluding_path = [d.strip() for d in project_excluding_path]

            for root, dirs, files in os.walk(project_root_path):
                for d in project_excluding_path:
                    if d in dirs:
                        dirs.remove(d)
                for fname in files:
                    if p.match(fname) != None:
                        files_fullpath_list.append(os.path.join(root, fname))
            return files_fullpath_list

prjmgr = _ProjectMgr()

# vim: set et sw=4 ts=4 ff=unix:
