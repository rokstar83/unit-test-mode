;;; ut-cppunit-framework.el --- Define a unit testing framework for cppunit

;; Copyright (c) 2013 Thomas Hartman (rokstar83@gmail.com)

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 2
;; of the License, or the License, or (at your option) any later
;; version.

;; This program is distributed in the hope that it will be useful
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;;; Commentary:

;; Define a testing framework for the cppunit testing

;;; Code:

(require 'dash)
(require 'ut)

(defun ut-cppunit-process-build-data (suite build-exit-status build-output)
  "Process build data generated by building SUITE with BUILD-EXIT-STATUS and BUILD-OUTPUT."
  (ht-set suite :build-status (if (= build-exit-status 0) 'built 'error))
  (ht-set suite :build-details (mapconcat #'identity build-ouput "")))

(defun ut-cppunit-process-run-data (suite run-exit-status run-output)
  "Process run data generated by running SUITE with RUN-EXIT-STATUS AND RUN-OUTPUT."
  (let ((results (read (mapconcat #'identity run-output ""))))
    (if (not (ut-resultsp))
        (ht-set suite :run-status 'error)
      (ht-set suite :run-status results))))

(defun ut-cppunit-setup-new-test-suite (test-suite)
  "Setup a new TEST-SUITE."
  (let* ((name (ut-test-suite-name test-suite))
         (dir (ut-test-suite-test-dir test-suite))
         (top-makefile.am-text (ut-format default-top-makefile.am test-suite))
         (src-makefile.am-text (ut-format default-src-makefile.am test-suite))
         (mainfile-text (ut-format default-mainfile test-suite))
         (testheader-text (ut-format default-testheader test-suite))
         (testsource-text (ut-format default-testsource test-suite))
         (project-name (ut-project-name)))
    (call-process-shell-command (concat "sed -i 's/\\(SUBDIRS =.*$\\)/\\1"
                                        (f-filename (ut-test-suite-test-dir test-suite))
                                        " /' " (f-join (f-parent (ut-test-suite-test-dir test-suite))
                                                       "Makefile.am")))
    (make-directory dir)
    (make-directory (f-join dir "src"))
    (make-directory (f-join dir "bin"))
    (make-directory (f-join dir "data"))
    (f-write-text top-makefile.am-text 'utf-8 (f-join dir "Makefile.am"))
    (f-write-text src-makefile.am-text 'utf-8 (f-join dir "src/Makefile.am"))
    (f-write-text (concat (cpp-header "main.cc" name project-name)
                          mainfile-text)
                  'utf-8 (f-join dir "src/main.cc"))
    (f-write-text (concat (cpp-header (format "%sTests.hh" name) name project-name)
                          testheader-text)
                  'utf-8 (f-join dir (format "src/%sTests.hh" name)))
    (f-write-text (concat (cpp-header (format "%sTests.cc" name) name project-name)
                          testsource-text)
                  'utf-8 (f-join dir (format "src/%sTests.cc" name)))))

(defun ut-cppunit-setup-new-project (ut-conf)
  "Setup a testing folders for a new project defined in UT-CONF."
  (unless (f-exists? (ut-test-dir ut-conf))
    (make-directory (ut-test-dir ut-conf)))
  (f-write-text "SUBDIRS = " 'utf-8 (f-join (ut-test-dir ut-conf) "Makefile.am")))

(defun cpp-header (file-name test-name project-name)
  "Combine the copyright and license to form MEGA HEADER!.
No wait, just a cpp header, sorry about that.
FILE-NAME, TEST-NAME and PROJECT-NAME are passed to copyright."
  (concat (mapconcat #'(lambda (x) (cpp-comment-pretty x))
                     (list (make-string 76 ?*)
                           (copyright file-name test-name (ut-project-name))
                           ""
                           gplv2-license
                           (make-string 76 ?*))
                     "\n")
          "\n"))

(defun cpp-comment-pretty (lines)
  "Apply /* and */ to each line in LINES and return the concatenation of all LINES."
  (if (stringp lines)
      (concat "/*" lines (make-string (- 76 (length lines)) ? ) "*/")
    (mapconcat #'identity
               (mapcar #'(lambda (line)
                           (concat "/*" line (make-string (- 76 (length line)) ? )
                                   "*/"))
                       lines)
               "\n")))

(defun copyright (file-name test-name project-name)
  "Return the copyright information.
Using FILE-NAME, TEST-NAME, and PROJECT-NAME"
  (list (concat " " file-name " --- " test-name " unit tests for " project-name)
        (concat " Copyright (c) 2013 " *full-name* " (" *email* ")")))

(defvar default-top-makefile.am
  "SUBDIRS = src")

(defvar default-src-makefile.am
  "AM_CPPFLAGS = -I%project-dir%/src -I/usr/local/include/
bin_PROGRAMS = %test-name%
%test-name%_SOURCES = main.cc %test-name%Tests.cc %test-name%Tests.hh
%test-name%_LDADD = cppunitsexpoutputter.so")

(defvar default-mainfile
"#include <cppunit/extensions/TestFactoryRegistry.h>
#include <cppunit/CompilerOutputter.h>
#include <cppunit/TestResult.h>
#include <cppunit/TestResultCollector.h>
#include <cppunit/TestRunner.h>
#include <cppunitsexpoutputter/SexpOutputter.h>

int main(int argc, char *argv[])
{
   CppUnit::TestResult controller;

   CppUnit::TestResultCollector result;
   controller.addListener(&result);

   CppUnit::TestRunner runner;
   runner.addTest(CppUnit::TestFactoryRegistry::getRegistry().makeTest());
   
   try {
      runner.run(controller);
      CppUnit::SexpOutputter outputter(&result, std::cout);
   } catch(...) {
   }
   
   return (result.wasSuccessful() ? 0 : 1);
}")

(defvar default-testheader
  "#ifndef %TEST-NAME%TESTS_HH_
#define %TEST-NAME%TESTS_HH_
#include <cppunit/TestFixture.h>
#include <cppunit/extensions/HelperMacros.h>

class %test-name%Tests : public CppUnit::TestFixture
{
\tCPPUNIT_TEST_SUITE(%test-name%Tests);
\tCPPUNIT_TEST_SUITE_END();

public:
\tvoid setup();
\tvoid tearDown();

};

CPPUNIT_TEST_SUITE_REGISTRATION(%test-name%Tests);

#endif /* %TEST-NAME%TESTS_HH_ */")

(defvar default-testsource
"#include \"%test-name%Tests.hh\"
#include <%test-name%.hh>

void %test-name%Tests::setup() {}

void %test-name%Tests::tearDown() {}
")

(defvar gplv2-license
  '(" This program is free software; you can redistribute it and/or"
    " modify it under the terms of the GNU General Public License"
    " as published by the Free Software Foundation; either version 2"
    " of the License, or the License, or (at your option) any later"
    " version."
    ""
    " This program is distributed in the hope that it will be useful"
    " but WITHOUT ANY WARRANTY; without even the implied warranty of"
    " MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the"
    " GNU General Public License for more details."))

(ut-define-framework cppunit
  :build-command "make -C %test-dir%"
  :build-filter #'ut-cppunit-process-build-data
  :run-command "%test-dir%/%test-name% --writer sexp"
  :run-filter #'ut-cppunit-process-run-data
  :new-test-suite #'ut-cppunit-setup-new-test-suite
  :new-project #'ut-cppunit-setup-new-project)

(provide 'ut-cppunit-framework)

;;; ut-cppunit-framework.el ends here
