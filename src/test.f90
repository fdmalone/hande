module tests

! Handy boilerplate module to use for testing and debugging code.

! Some rules:
! * Do commit test procedures which are generic or frequently useful.
! * Don't commit (at least not permanently) code that tests development work.
!   If you do commit such code, please tidy up and remove it once it stops being
!   useful.
! * Don't keep test calls in production code, which should be as lean and as
!   fast as possible.
! * Keep the modules on which this module depends to a minimum to avoid
!   potential circular dependency problems.
! * Don't assume old code in here is compatible with the existing code---caveat
!   emptor!

use const

implicit none

contains

    subroutine assert_statement(test)

        ! Exit if a test is not met.
        ! If this proves useful, then it might best belong in the utils module.

        ! In:
        !    test: logical statement which ought(!) to be true.

        use errors, only: stop_all

        logical, intent(in) :: test

        if (test) call stop_all('assert_statement','assertion is false')

    end subroutine assert_statement

end module tests