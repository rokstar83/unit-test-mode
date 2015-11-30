;;; ut-cppunit-framework.el --- Define a unit testing framework for cppunit

;; Copyright (c) 2013 Thomas Hartman (thomas.lees.hartman@gmail.com)

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
(require 's)
(require 'ut)
(require 'ut-common-framework)

(defgroup ut-cppunit nil
  "cppunit integration for ut mode"
  :prefix "ut-cppunit"
  :group 'ut)

;;; Project level files

(defcustom ut-cppunit-configure.ac "ut-cppunit-configure_ac.m4"
  "Default text for project level configure.ac."
  :group 'ut-cppunit
  :risky t
  :type 'string)

(defcustom ut-cppunit-top-makefile.am "ut-cppunit-top-makefile_am.m4"
  "Default Makefile.am at the project root."
  :group 'ut-cppunit
  :risky t
  :type 'string)

(defcustom ut-cppunit-src-makefile.am "ut-cppunit-src-makefile_am.m4"
  "Default Makefile.am in the project src dir."
  :group 'ut-cppunit
  :risky t
  :type 'string)

(defcustom ut-cppunit-tests-makefile.am "ut-cppunit-tests-makefile_am.m4"
  "Default Makefile.am in the project tests dir."
  :group 'ut-cppunit
  :risky t
  :type 'string)

;;; Test Suite level files

(defcustom ut-cppunit-test-suite-top-makefile.am
  "ut-cppunit-test-suite-top-makefile_am.m4"
  "Default value of the top makefile for a test suite."
  :group 'ut-cppunit
  :risky t
  :type 'string)

(defcustom ut-cppunit-test-suite-src-makefile.am
  "ut-cppunit-test-suite-src-makefile_am.m4"
  "Default src level makefile for a test suite."
  :group 'ut-cppunit
  :risky t
  :type 'string)

(defcustom ut-cppunit-test-suite-main.cc "ut-cppunit-test-suite-main_cc.m4"
  "Default test-suite main file."
  :group 'ut-cppunit
  :risky t
  :type 'string)

(defcustom ut-cppunit-test-suite-header.hh "ut-cppunit-test-suite-header_hh.m4"
  "Default header file for a test suite."
  :group 'ut-cppunit
  :risky t
  :type 'string)

(defcustom ut-cppunit-test-suite-source.cc "ut-cppunit-test-suite-source_cc.m4"
  "Default source file for a test suite."
  :group 'ut-cppunit
  :risky t
  :type 'string)

;;; Test suite text

(defcustom ut-cppunit-test-cppunit-text "ut-cppunit-test-cppunit-text.m4"
  "Default code to add a new test to a cppunit test-suite."
  :group 'ut-cppunit
  :risky t
  :type 'string)

(defcustom ut-cppunit-test-proto-text "ut-cppunit-test-proto-text.m4"
  "Default prototype definition of a test function."
  :group 'ut-cppunit
  :risky t
  :type 'string)

(defcustom ut-cppunit-test-impl-text "ut-cppunit-test-impl-text.m4"
  "Default implementation definition of a test function."
  :group 'ut-cppunit
  :risky t
  :type 'string)

(defcustom ut-cppunit-gdb-cmd-opts
  "gdb -i=mi %s"
  "GDB command options."
  :group 'ut-cppunit
  :risky t
  :type 'string)

(defun ut-cppunit-build-process (conf test-suite buffer)
  "Return a process used to build CONF/TEST-SUITE in BUFFER."
  (start-process (s-concat "build-" (ut-test-suite-name test-suite-name))
                 buffer "make" "-C" (ut-test-suite-test-dir test-dir)))

(defun ut-cppunit-process-build-data (test-suite build-exit-status build-output)
  "Process build data generated by building TEST-SUITE with BUILD-EXIT-STATUS and BUILD-OUTPUT."
  (ht-set suite :build-status (if (= build-exit-status 0) 'built 'error))
  (ht-set suite :build-details (mapconcat #'identity build-output "")))

(defun ut-cppunit-run-process (conf test-suite buffer)
  "Return a process used to run CONF/TEST-SUITE in BUFFER."
  (start-process (s-concat "run-" (ut-test-suite-name test-suite-name))
                 buffer (format "%s/src/%s" (ut-test-suite-dir test-suite)
                                (ut-test-suite-name test-suite))
                 "--writer" "sexp"))

(defun ut-cppunit-process-run-data (test-suite run-exit-status run-output)
  "Process run data generated by running TEST-SUITE with RUN-EXIT-STATUS AND RUN-OUTPUT."
  (let ((results (read (mapconcat #'identity run-output ""))))
    (if (not (ut-resultp))
        (ht-set suite :run-status 'error)
      (ht-set suite :run-status results))))

(defun ut-cppunit-debug-test-suite (conf test-suite)
  "Debug CONF/TEST-SUITE."
  (let ((path (f-join (ut-conf-test-dir conf) (ut-test-suite-test-dir test-suite)
                      "src/" (format "%sTests" (ut-test-suite-name test-suite)))))
    (gdb (format ut-cppunit-gdb-cmd-opts path))))


(defun ut-cppunit-test-suite-find-source (conf test-suite)
  "Find the source file associated with CONF/TEST-SUITE."
  (f-join (ut-test-suite-test-dir suite)
          (format "src/%sTests.cc" (ut-test-suite-name suite))))

(defun ut-cppunit-test-suite-new (conf test-suite)
  "Generate cppunit files and directory structures for CONF/TEST-SUITE."
  (let* ((name (ut-test-suite-name test-suite))
         (root-dir (f-join (ut-conf-test-dir conf)
                           (ut-test-suite-test-dir test-suite)))
         (src-dir (f-join test-suite-dir (ut-test-suite-src-dir test-suite))))
    ;; setup folder structure
    (f-mkdir root-dir)
    (f-mkdir src-dir)
    ;; setup default files
    (mapc #'(lambda (pair)
              (ut-m4-expand-file (f-join ut--pkg-root "m4" "cppunit" (car pair))
                                 (cdr pair)
                                 (ht-merge conf test-suite
                                           (ut-get-license-info))))
          `((,ut-cppunit-test-suite-top-makefile.am .
             ,(f-join root-dir "Makefile.am"))
            (,ut-cppunit-test-suite-src-makefile.am .
             ,(f-join src-dir "Makefile.am"))
            (,ut-cppunit-test-suite-main.cc .
             ,(f-join src-dir "main.cc"))
            (,ut-cppunit-test-suite-header.hh .
             ,(f-join src-dir (format "%sTests.hh" name)))
            (,ut-cppunit-test-suite-source.cc .
             ,(f-join src-dir (format "%sTests.cc" name)))))
    (ut-add-makefile.am-subdir name (f-join (ut-conf-test-dir conf) "Makefile.am"))
    (ut-add-ac-config-files (f-relative root-dir (ut-conf-project-dir conf))
                            (f-join (ut-conf-project-dir conf) "configure.ac"))
    (ut-add-ac-config-files (f-relative src-dir (ut-conf-project-dir conf))
                            (f-join (ut-conf-project-dir conf) "configure.ac"))))

(defun ut-cppunit-test-new (conf test-suite test-name)
  "Add CONF/TEST-SUITE/TEST-NAME."
  (ut-cppunit-test-new-hdr conf test-suite test-name)
  (ut-cppunit-test-new-src conf test-suite test-name))

(defun ut-cppunit-test-new-hdr (conf test-suite test-name)
  "Add CONF/TEST-SUITE/TEST-NAME stub function to the TEST-SUITE hdr file."
  (let ((hdr-file-name (ut-cppunit-test-suite-hdr-file conf test-suite))
        (proto-text (ut-m4-expand-text (f-read (f-join ut--pkg-root "m4" "cppunit"
                                                       ut-cppunit-test-proto-text))
                                       (ht (:test-name test-name))))
        (cppunit-text (ut-m4-expand-text (f-read (f-join ut--pkg-root "m4" "cppunit"
                                                        ut-cppunit-test-cppunit-text))
                                         (ht (:test-name test-name)))))
    ;; Add function prototype
    (ut-insert-into-file proto-text hdr-file-name
                         (ut-cppunit-test-suite-proto-sentinel-line hdr-file-name))
    (ut-insert-into-file cppunit-text hdr-file-name
                         (ut-cppunit-test-suite-cppunit-sentinel-line hdr-file-name))
;    (ut-revert-switch-buffer hdr-file-name)
    ))

(defun ut-cppunit-test-new-src (conf test-suite test-name)
  "Add the new test to the main testing objects source file.

CONF/TEST-SUITE/TEST-NAME."
  (let ((src-file-name (ut-cppunit-test-suite-src-file conf test-suite))
        (impl-text (ut-m4-expand-text (f-read (f-join ut--pkg-root "m4" "cppunit"
                                                      ut-cppunit-test-impl-text))
                                      (ht (:test-name test-name)
                                          (:test-suite-name
                                           (ut-test-suite-name test-suite))))))
    (ut-insert-into-file impl-text src-file-name
                         (ut-cppunit-test-suite-impl-sentinel-line src-file-name))))

(defun ut-cppunit-test-suite-hdr-file (conf test-suite)
  "Return the path to the header file for CONF/TEST-SUITE."
  (f-join (ut-conf-test-dir conf)
          (ut-test-suite-test-dir test-suite)
          (ut-test-suite-src-dir test-suite)
          (format "%sTests.hh" (ut-test-suite-name test-suite))))

(defun ut-cppunit-test-suite-src-file (conf test-suite)
  "Return the path to the header file for CONF/TEST-SUITE."
  (f-join (ut-conf-test-dir conf)
          (ut-test-suite-test-dir test-suite)
          (ut-test-suite-src-dir test-suite)
          (format "%sTests.cc" (ut-test-suite-name test-suite))))

(defun ut-cppunit-create-test-suite-subdirs (test-suite-dir)
  "Create the directory structure for a test suite at TEST-SUITE-DIR."
  (mapc #'(lambda (dir)
           (unless (f-exists? dir)
             (make-directory dir)))
        (list test-suite-dir
              (f-join test-suite-dir "src")
              (f-join test-suite-dir "bin")
              (f-join test-suite-dir "data"))))

(defun ut-cppunit-setup-new-project (conf)
  "Setup a testing folders for a new project defined in CONF."
  (unless (f-exists? (ut-conf-test-dir conf))
    (make-directory (ut-conf-test-dir conf)))
  (f-write-text "SUBDIRS = " 'utf-8 (f-join (ut-conf-test-dir conf) "Makefile.am")))

(defun ut-cppunit-cpp-header (file-name test-name project-name)
  "Combine the copyright and license to form MEGA HEADER!.
No wait, just a cpp header, sorry about that.
FILE-NAME, TEST-NAME and PROJECT-NAME are passed to copyright."
  (concat (mapconcat #'(lambda (x) (ut-cppunit-comment-pretty x))
                     (list (make-string 76 ?*)
                           (copyright file-name test-name project-name)
                           ""
                           gplv2-license
                           (make-string 76 ?*))
                     "\n")
          "\n"))

(defun ut-cppunit-comment-pretty (lines)
  "Apply /* and */ to each line in LINES and return the concatenation of all LINES."
  (if (stringp lines)
      (concat "/*" lines (make-string (- 76 (length lines)) ? ) "*/")
    (mapconcat #'identity
               (mapcar #'(lambda (line)
                           (concat "/*" line (make-string (- 76 (length line)) ? )
                                   "*/"))
                       lines)
               "\n")))

(defun ut-cppunit-test-suite-proto-sentinel-line (hdr-file-name)
  "Find and return the line in test-suite containing the sentinel in HDR-FILE-NAME."
  (let ((lineno (ut-find-line-in-file "// END TESTS" hdr-file-name)))
    (when (null lineno)
      (error "Unable to find header sentinel in `%s'" hdr-file-name))
    lineno))

(defun ut-cppunit-test-suite-cppunit-sentinel-line (hdr-file-name)
  "Find and return the line in HDR-FILE-NAME with the cppunit sentinel."
  (let ((lineno (ut-find-line-in-file "CPPUNIT_TEST_SUITE_END();" hdr-file-name)))
    (when (null lineno)
      (error "Unable to find cppunit sentinel in `%s'" hdr-file-name))
    lineno))

(defun ut-cppunit-test-suite-impl-sentinel-line (src-file-name)
  "Find and return the line in test-suite containing the sentinel in SRC-FILE-NAME."
  (let ((lineno (ut-find-line-in-file "// END TESTS" src-file-name)))
    (when (null lineno)
      (error "Unable to find header sentinel in `%s'" src-file-name))
    lineno))

(ut-define-framework cppunit
  :build-process-fn #'ut-cppunit-build-process
  :build-filter-fn #'ut-cppunit-process-build-data
  :run-process-fn #'ut-cppunit-run-process
  :run-filter-fn #'ut-cppunit-process-run-data
  :debug-fn #'ut-cppunit-debug-test-suite
  :find-source-fn #'ut-cppunit-test-suite-find-source
  :new-project-fn #'ut-cppunit-setup-new-project
  :new-test-suite-fn #'ut-cppunit-test-suite-new
  :new-test-fn #'ut-cppunit-test-new)

;; Everything past here may be a mistake

(defvar *ut-cppunit-autotool-touch-files*
  (list "NEWS" "AUTHORS" "COPYING" "LICENSE" "INSTALL" "README" "ChangeLog"))

(defvar *ut-cppunit-directories* (list "config" "src" "tests"))

(defun ut-cppunit-setup-autotools-env (dir &optional project-name)
  "Setup all necessary files for auto tools in DIR with PROJECT-NAME."
  (when (null project-name)
    (setf project-name (car (reverse (f-split (f-expand dir))))))
  (mapc #'f-touch (mapcar #'(lambda (p) (f-join dir p))
                          *ut-cppunit-autotool-touch-files*))
  (mapc #'f-mkdir (mapcar #'(lambda (p) (f-join dir p))
                          *ut-cppunit-directories*))
  (ut-m4-expand-file (f-join ut--pkg-root "m4" "cppunit" ut-cppunit-configure.ac)
                     (f-join dir "configure.ac")
                     (ht (:project-name project-name)))
  (ut-m4-expand-file (f-join ut--pkg-root "m4" "cppunit"
                             ut-cppunit-top-makefile.am)
                     (f-join dir "Makefile.am")
                     (ht))
  (ut-m4-expand-file (f-join ut--pkg-root "m4" "cppunit"
                             ut-cppunit-src-makefile.am)
                     (f-join "src/Makefile.am")
                     (ht (:project-name project-name)))
  (ut-m4-expand-file (f-join ut--pkg-root "m4" "cppunit"
                             ut-cppunit-tests-makefile.am)
                     (f-join "tests/Makefile.am")
                     (ht)))

(defun ut-new-cppunit-project (project-dir project-name)
  "Create a barebones cppunit PROJECT-DIR for PROJECT-NAME."
  (interactive
   (let* ((name (read-string "Project Name: "))
          (dir (read-directory-name "Project Directory: " ut-root-project-dir
                                    (f-join ut-root-project-dir name)
                                    nil (f-join ut-root-project-dir name))))
     (list name dir)))
  (ut-cppunit-setup-autotools-env project-dir project-name))

(defun ut-get-license-info ()
  "Return the default license file, this is largely a stub."
  (ht (:license-info "/* LICENSE HERE */")))

(provide 'ut-cppunit-framework)

;;; ut-cppunit-framework.el ends here
