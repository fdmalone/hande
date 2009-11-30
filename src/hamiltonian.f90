module hamiltonian

use const
use basis
use determinants
use hubbard

implicit none

real(dp), allocatable :: hamil(:,:)

contains

    subroutine generate_hamil()

        integer :: ierr, i, j
        type(excit) :: excitation
        integer :: root_det(nel)

        allocate(hamil(ndets,ndets), stat=ierr)

        do i=1, ndets
            do j=i, ndets
                if (dets(i)%Ms == dets(j) % Ms) then
                    excitation = get_excitation(dets(i)%f, dets(j)%f)
                    if (excitation%nexcit <= 2) then
                        root_det = decode_det(dets(i)%f)
                        hamil(i,j) = get_hmatel(root_det, excitation)
                    else
                        hamil(i,j) = 0.0_dp
                    end if
                else
                    hamil(i,j) = 0.0_dp
                end if
            end do
        end do

        ! Fill in rest of Hamiltonian matrix.  In this case the Hamiltonian is
        ! symmetric (rather than just Hermitian).
        do i=1,ndets
            do j=1,i-1
                hamil(i,j) = hamil(j,i)
            end do
        end do

    end subroutine generate_hamil
    
    pure function get_hmatel(root_det, excitation) result(hmatel)

        real(dp) :: hmatel
        type(excit), intent(in) :: excitation
        integer, intent(in) :: root_det(nel)
        integer :: i, j

        hmatel = 0.0_dp

        select case(excitation%nexcit)
        case(0)

            ! One electron operator
            do i = 1, nel
                hmatel = hmatel + get_one_e_int(root_det(i), root_det(i))
            end do

            ! Two electron operator
            do i = 1, nel
                do j = 1, nel
                    hmatel = hmatel + get_two_e_int(root_det(i), root_det(j), root_det(i), root_det(j))
                end do
            end do

        case(1)

            ! One electron operator
            hmatel = hmatel + get_one_e_int(excitation%from_orb(1), excitation%to_orb(1)) 

            ! Two electron operator
            do i = 1, nel
                hmatel = hmatel + get_two_e_int(root_det(i), excitation%from_orb(1), root_det(i), excitation%to_orb(1))
            end do

        case(2)

            ! Two electron operator
            hmatel = get_two_e_int(excitation%from_orb(1), excitation%from_orb(2), excitation%to_orb(1), excitation%to_orb(2))

        end select

    end function get_hmatel

end module hamiltonian
