! SPDX-FileCopyrightText: 2026 Miguel Amaral
! SPDX-License-Identifier: BSD-3-Clause
!
! Example draw routines built on src/threefry_mod.f90:
! a table index, a uniform, and a normal plus a uniform.
! Each a pure function of a (ctr0, ctr1, key) triple of default integers.
! Omitting the second part of the key from the arguments lets functions in
! this module use it for multiple draws per call (a multistream approach as described in Random123).
! Some functions also only use half of the output, allowing repeats to happen.


module rand_mod

  use threefry_mod, only: i8, m32, threefry2x32

  implicit none

  private
  public :: i8, rand_index, rand_uniform, rand_normal_uniform

  integer, parameter :: r8=kind(1.0d0)

  ! compiler checks
  integer(kind=kind(0)-1000*abs(bit_size(0)-32)), parameter :: assert_int_is_32_bit = 0
  integer(kind=kind(0)-1000*abs(digits(1.0)-24)-1000*abs(radix(1.0)-2)), parameter :: assert_real_is_single = 0

contains

  !> Index in [1,nmax].
  elemental function rand_index(ctr0,ctr1,key,nmax)

    implicit none

    integer, intent(in) :: ctr0,ctr1,key
    integer, intent(in) :: nmax   ! size of the table being indexed into
    integer :: rand_index

    integer(kind=i8) :: w0, w1
    call threefry2x32(iand(int(ctr0,i8),m32), iand(int(ctr1,i8),m32), &
                      iand(int(key,i8),m32), 0_i8, w0, w1)

    rand_index=int(modulo(w0,int(nmax,i8)))+1

  end function rand_index

  !> Uniform deviate, strictly in [0,1).
  elemental function rand_uniform(ctr0,ctr1,key)
    implicit none

    integer, intent(in) :: ctr0,ctr1,key
    real :: rand_uniform

    integer(kind=i8) :: w0, w1
    call threefry2x32(iand(int(ctr0,i8),m32), iand(int(ctr1,i8),m32), &
                      iand(int(key,i8),m32), 0_i8, w0, w1)

    ! map [0,2^32) to [0,1).
    rand_uniform=real(ishft(w0,-8))*(2.0**(-24))

  end function rand_uniform

  !> One standard normal deviate 'g' and one independent uniform 'u' on [0,1)
  !> (an example that makes use of the reserved key space)
  elemental subroutine rand_normal_uniform(ctr0,ctr1,key,g,u)

    ! uses the basic form of Box-Muller.
    ! R is bounded: u1 smallest value is 2**(-32) so |g| <= 6.66 sigma.
    ! the pair (X,Y) falls outside that radius with probability 2**(-32) ~= 2.3e-10;
    ! a true normal exceeds 6.66 with probability ~2.7e-11.

    implicit none

    integer, intent(in) :: ctr0,ctr1,key
    real, intent(out) :: g  ! standard normal
    real, intent(out) :: u  ! uniform on [0,1), independent of g

    real(kind=r8), parameter :: twopi=6.283185307179586_r8
    integer(kind=i8) :: c0,c1,k0,w0,w1,v0,v1
    real(kind=r8) :: u1,u2

    c0=iand(int(ctr0,i8),m32)
    c1=iand(int(ctr1,i8),m32)
    k0=iand(int(key,i8),m32)

    call threefry2x32(c0,c1,k0,1_i8,w0,w1)   ! the Box-Muller pair
    call threefry2x32(c0,c1,k0,2_i8,v0,v1)   ! the independent uniform

    u1=real(1+w0,r8)*(2.0**(-32)) ! (0,1]
    u2=real(w1,r8)*(2.0**(-32)) ! [0,1)
    g=real(sqrt(-2.0_r8*log(u1))*cos(twopi*u2))
    u=real(ishft(v0,-8))*(2.0**(-24))

  end subroutine rand_normal_uniform



end module rand_mod
