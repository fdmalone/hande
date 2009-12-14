module hubbard

! Momentum space formulation of the Hubbard model.

use basis
use system
use basis

implicit none

contains

    subroutine init_basis_fns()

        ! Produce the basis functions.  The number of wavevectors is
        ! equal to the number of sites in the crystal cell (ie the number
        ! of k-points used to sample the FBZ of the primitive cell).
        ! From the cell parameters and the "tilt" used (if any) generate
        ! the list of wavevectors and hence the kinetic energy associated
        ! with each basis function (two per wavevector to account for spin).

        use m_mrgref, only: mrgref
        use errors, only: stop_all
        use parallel, only: parent

        integer :: limits(3,3), nmax(3), kp(3) ! Support a maximum of 3 dimensions.
        integer :: i, j, k, ibasis, ierr
        type(basis_fn), allocatable, target :: tmp_basis_fns(:)
        type(basis_fn), pointer :: basis_fn_p
        integer, allocatable :: basis_fns_ranking(:)

        nbasis = 2*nsites

        ! Fold the crystal cell into the FBZ.
        ! The k-points must be integer multiples of the reciprocal lattice
        ! vectors of the crystal cell (so that the wavefunction is periodic in
        ! the crystal cell) and fall within the first Brillouin zone of the
        ! primitive unit cell (so that a unique set of k-points are chosen).
        ! The volume of the FBZ is inversely proportional to the volume of the
        ! cell, and so the number of sites in the crystal cell is equal to the
        ! number of reciprocal crystal cells in the FBZ of the unit cell and 
        ! hence this gives the required number of wavevectors.


        ! Maximum limits...
        ! [Does it show that I've been writing a lot of python recently?]
        nmax = 0 ! Set nmax(i) to be 0 for unused higher dimensions.
        limits = 0
        ! forall is a poor substitute for list comprehension. ;-)
        forall (i=1:ndim)
            forall (j=1:ndim, lattice(i,j) /= 0) 
                limits(i,j) = abs(nint(box_length(i)**2/(2*lattice(i,j))))
            end forall
            nmax(i) = maxval(limits(:,i))
        end forall

        allocate(basis_fns(nbasis), stat=ierr)
        allocate(tmp_basis_fns(nbasis), stat=ierr)
        allocate(basis_fns_ranking(nbasis), stat=ierr)

        ibasis = 0
        do k = -nmax(3), nmax(3)
            do j = -nmax(2), nmax(2)
                do i = -nmax(1), nmax(1)
                    ! kp is the Wavevector in terms of the reciprocal lattice vectors of
                    ! the crystal cell.
                    kp = (/ i, j, k /)
                    if (in_FBZ(kp(1:ndim))) then
                        if (ibasis==nbasis) then
                            call stop_all('init_basis_fns','Too many basis functions found.')
                        else
                            ! Have found an allowed wavevector.
                            ! Add 2 spin orbitals to the set of the basis functions.
                            ibasis = ibasis + 1
                            call init_kpoint(tmp_basis_fns(ibasis), kp(1:ndim), 1)
                            ibasis = ibasis + 1
                            call init_kpoint(tmp_basis_fns(ibasis), kp(1:ndim), -1)
                        end if
                    end if
                end do
            end do
        end do

        if (ibasis /= nbasis) call stop_all('init_basis_fns','Not enough basis functions found.')

        ! Sort by kinetic energy.
        call mrgref(tmp_basis_fns(:)%kinetic, basis_fns_ranking)
        do i = 1, nbasis
            ! Can't set a kpoint equal to another kpoint as then the k pointers
            ! can be assigned whereas we want to *copy* the values.
            basis_fn_p => tmp_basis_fns(basis_fns_ranking(i))
            call init_kpoint(basis_fns(i), basis_fn_p%k, basis_fn_p%ms)
            deallocate(tmp_basis_fns(basis_fns_ranking(i))%k, stat=ierr)
        end do
        deallocate(tmp_basis_fns, stat=ierr)
        deallocate(basis_fns_ranking, stat=ierr)

        if (parent) then
            write (6,'(1X,a15,/,1X,15("-"),/)') 'Basis functions'
            write (6,'(1X,a7)', advance='no') 'k-point'
            do i = 1, ndim
                write (6,'(3X)', advance='no')
            end do
            write (6,'(a,4X,a7)') 'ms','kinetic'
            do i = 1, nbasis
                call write_kpoint(basis_fns(i), new_line=.true.)
            end do
            write (6,'()')
        end if

    end subroutine init_basis_fns

    subroutine end_basis_fns()

        ! Clean up basis functions.

        integer :: ierr, i

        do i = 1, nbasis
            deallocate(basis_fns(i)%k, stat=ierr)
        end do
        deallocate(basis_fns, stat=ierr)

    end subroutine end_basis_fns

    pure function get_one_e_int(phi1, phi2) result(one_e_int)

        ! In:
        !    phi1: index of a momentum-space basis function.
        !    phi2: index of a momentum-space basis function.
        ! Returns:
        !    <phi1 | T | phi2> where T is the kinetic energy operator.

        real(dp) :: one_e_int
        integer, intent(in) :: phi1, phi2

        ! T is diagonal in the basis of momentum-space functions.
        if (phi1 == phi2) then
            one_e_int = basis_fns(phi1)%kinetic
        else
            one_e_int = 0.0_dp
        end if

    end function get_one_e_int

    elemental function get_two_e_int(phi1, phi2, phi3, phi4) result(two_e_int)

        ! In:
        !    phi1: index of a momentum-space basis function.
        !    phi2: index of a momentum-space basis function.
        !    phi3: index of a momentum-space basis function.
        !    phi4: index of a momentum-space basis function.
        ! Returns:
        !    The anti-symmetrized integral <phi1 phi2 || phi3 phi4>.

        real(dp) :: two_e_int
        integer, intent(in) :: phi1, phi2, phi3, phi4

        ! <phi1 phi2 || phi3 phi4>
        two_e_int = 0.0_dp

        ! The integral < k_1 k_2 | U | k_3 k_4 > = U/N \delta_{k_1+k2,k_3+k_4}
        ! where the delta function requires crystal momentum is conserved up to
        ! a reciprocal lattice vector.

        ! <phi1 phi2 | phi3 phi4>
        if (spin_symmetry(phi1, phi3) .and. spin_symmetry(phi2, phi4)) then
            if (momentum_conserved(phi1, phi2, phi3, phi4)) then
                two_e_int = hubu/nsites
            end if
        end if

        ! <phi1 phi2 | phi4 phi3>
        if (spin_symmetry(phi1, phi4) .and. spin_symmetry(phi2, phi3)) then
            if (momentum_conserved(phi1, phi2, phi4, phi3)) then
                two_e_int = two_e_int - hubu/nsites
            end if
        end if

    end function get_two_e_int

    elemental function momentum_conserved(i, j, k, l) result(conserved)

        ! In:
        !    i: index of a momentum-space basis function.
        !    j: index of a momentum-space basis function.
        !    k: index of a momentum-space basis function.
        !    l: index of a momentum-space basis function.
        ! Returns:
        !    True if crystal momentum is conserved in the integral <k_i k_j | U | k_k k_l>
        !    i.e. if k_i + k_j - k_k -k_l = 0 up to a reciprocal lattice vector.

        logical :: conserved
        integer, intent(in) :: i, j, k, l
        integer :: delta_k(ndim)

        ! k_i + k_j - k_k -k_l in units of the reciprocal lattice vectors of the
        ! crystal cell.
        delta_k = basis_fns(i)%k + basis_fns(j)%k - basis_fns(k)%k - basis_fns(l)%k

        conserved = is_reciprocal_lattice_vector(delta_k)

    end function momentum_conserved

end module hubbard
