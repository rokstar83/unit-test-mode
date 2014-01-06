;;; test-ut-test-suite.el --- Tests for ut

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

;;; Code:

(require 'test-helpers)
(require 'file-utils)

;; test test-suite addition and removal functions

(ert-deftest test-ut-new-test-suite ()
  (with-temporary-dir
   (ut-new-conf ".tests" "foo" (f-expand "./") (f-expand "./"))
   (make-directory (f-expand "./tests"))
   (should (= (ut-test-suite-count) 0))
   (ut-new-test-suite "foo" (f-expand "./tests/foo") 'echo)
   (should (ut-test-suite-p (ut-get-test-suite "foo")))
   (should (= (ut-test-suite-count) 1))
   (should (string= (ut-test-suite-name (first (ut-test-suites))) "foo"))
   (should (string= (ut-test-suite-test-dir (first (ut-test-suites)))
                    (f-expand "./tests/foo")))
   (should (equal (ut-test-suite-framework (first (ut-test-suites))) 'echo))))

(ert-deftest test-ut-adding-and-deleting-suites ()
  (with-temporary-dir
   (ut-new-conf ".tests" "foo" (f-expand "./") (f-expand "./"))
   (make-directory (f-expand "./tests"))
   (should (= (ut-test-suite-count) 0))
   (ut-new-test-suite "foo" (f-expand "./tests/foo") 'echo)
   (should (= (ut-test-suite-count) 1))
   (ut-del-test-suite "foo")
   (should (= (ut-test-suite-count) 0))))

(ert-deftest test-errors-on-add-and-del-test-suite ()
  (with-temporary-dir
   (push 'echo ut-frameworks)
   (ut-new-conf ".tests" "foo" (f-expand "./") (f-expand "./"))
   (make-directory (f-expand "./tests"))
   (should (= (ut-test-suite-count) 0))
   (should-error (ut-del-test-suite "foo")
                 "Test suite 'foo' does not exist")
   (ut-new-test-suite "foo" (f-expand "./tests/foo") 'echo)
   (should-error (ut-new-test-suite "foo" (f-expand "./tests") 'echo)
                 "Test suite 'foo' already exists")
   (should-error (ut-del-test-suite "bar")
                 "Test suite 'bar' does not exist")))

(ert-deftest test-ut-get-test-suite ()
  (with-temporary-dir
   (ut-new-conf ".tests" "foo" (f-expand "./") (f-expand "./"))
   (make-directory (f-expand "./tests"))
   (let ((suite (ut-new-test-suite "foo" (f-expand "./tests/foo") 'echo)))
     (should (equal (ut-get-test-suite "foo") suite)))
   (let ((suite (ut-new-test-suite "bar" (f-expand "./tests/bar") 'echo)))
     (should (equal (ut-get-test-suite "bar") suite)))
   (should-error (ut-get-test-suite "baz") "Test suite 'baz' does not exist")))

(provide 'test-ut-test-suite)

;;; test-ut-test-suite.el ends here
