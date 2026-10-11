! SPDX-FileCopyrightText: 2010-2012 D. E. Shaw Research
! SPDX-FileCopyrightText: 2026 Miguel Amaral
! SPDX-License-Identifier: BSD-3-Clause
! Translated from Random123's threefry.h. License text: LICENSE.
!
! Threefry-2x32 (Salmon, Moraes, Dror & Shaw, SC'11; reference code
! DEShawResearch/random123), a counter-based pseudorandom function, in
! portable Fortran 95.
!
! Self-contained: this file has no dependencies, so it can be copied into
! another code base as is, or compiled alongside it and brought in with
! `use threefry_mod`.

module threefry_mod

  implicit none

  private
  public :: i8, m32, tf_rounds, threefry2x32, threefry2x32_r
  ! 64-bit kind and constants used by the generator below
  integer, parameter :: i8=selected_int_kind(18)
  integer, parameter :: i4=selected_int_kind(9)  ! 32-bit, for tf_rotl32
  integer(kind=i8), parameter :: m32=4294967295_i8        ! 2**32-1
  integer(kind=i8), parameter :: tf_kschedule=466688986_i8 ! 0x1BD11BDA
  integer, parameter :: tf_rot(8)=(/13,15,26,6,17,29,16,24/)
  integer, parameter :: tf_rounds=20  ! Random123 default

  ! compiler checks
  integer(kind=kind(0)-1000*abs(bit_size(0_i8)-64)), parameter :: &
  assert_i8_is_64_bit = 0
  integer(kind=kind(0)-1000*int(abs(iand(int(-1,i8),m32)-m32))), parameter :: &
  assert_twos_complement_widening = 0
  integer(kind=kind(0)-1000*abs(bit_size(0_i4)-32)), parameter :: &
  assert_i4_is_32_bit = 0

contains

  !> Rotate a 32-bit word, held in an i8, left by n bits.
  pure function tf_rotl32(x,n) result(r)

    implicit none
    integer(kind=i8), intent(in) :: x
    integer, intent(in) :: n
    integer(kind=i8) :: r
    integer(kind=i4) :: y
    ! rotate as two logical shifts, instead of an existing function
    ! slow alternatives dropped:
    !   ishftc(y,n): on the i4 is a library call on ifx
    !   ishftc(x,n,32) on the i8 is a library call on gfortran.
    !

    ! map x that is in [0,2^32) to (-2^31,2^31) so it fits in an i4
    ! in binary the 32nd bit of x becomes the sign bit of the i4
    ! and the other 31 bits become the number
    y=int(x-ishft(ibits(x,31,1),32),i4)

    ! gfortran and ifx both compile this to one rotate instruction when n is
    ! a constant, as in threefry2x32.
    ! masking necessary to deal with complement bits when y<0.
    r=iand(int(ior(ishft(y,n),ishft(y,n-32)),i8),m32)

  end function tf_rotl32

  !> Threefry-2x32 at nrounds rounds.
  !> Counter (c0,c1) and key (k0,k1) map to two 32-bit words (o0,o1).
  !> Each word is held in an i8; only its low 32 bits are used, the rest are kept zero.
  !> For testing other round counts; callers use threefry2x32.
  pure subroutine threefry2x32_r(c0,c1,k0,k1,nrounds,o0,o1)

    implicit none

    integer(kind=i8), intent(in)  :: c0,c1,k0,k1
    integer, intent(in)           :: nrounds
    integer(kind=i8), intent(out) :: o0,o1

    integer(kind=i8) :: ks(0:2), x0, x1
    integer :: r, i

    ks(0)=iand(k0,m32)
    ks(1)=iand(k1,m32)
    ks(2)=iand(ieor(ieor(tf_kschedule,ks(0)),ks(1)),m32)

    x0=iand(c0+ks(0),m32)
    x1=iand(c1+ks(1),m32)

    do r=0,nrounds-1
      x0=iand(x0+x1,m32)
      x1=tf_rotl32(x1,tf_rot(mod(r,8)+1))
      x1=ieor(x1,x0)
      if (mod(r+1,4)==0) then
        i=(r+1)/4
        x0=iand(x0+ks(mod(i,3)),m32)
        x1=iand(x1+ks(mod(i+1,3))+int(i,i8),m32)
      end if
    end do

    o0=x0
    o1=x1

  end subroutine threefry2x32_r

  !> Threefry-2x32 unrolled at the default tf_rounds = 20 rounds
  !> 35-70% fewer cycles than threefry2x32_r, depending on the compiler.
  elemental subroutine threefry2x32(c0,c1,k0,k1,o0,o1)

    implicit none

    integer(kind=i8), intent(in)  :: c0,c1,k0,k1
    integer(kind=i8), intent(out) :: o0,o1

    integer(kind=i8) :: ks(0:2), x0, x1
    integer :: i

    ks(0)=iand(k0,m32)
    ks(1)=iand(k1,m32)
    ks(2)=iand(ieor(ieor(tf_kschedule,ks(0)),ks(1)),m32)

    x0=iand(c0+ks(0),m32)
    x1=iand(c1+ks(1),m32)

    do i=1,tf_rounds/4
      ! four rounds, alternating between the two halves of tf_rot
      if (mod(i,2)==1) then
        x0=iand(x0+x1,m32); x1=ieor(tf_rotl32(x1,13),x0)
        x0=iand(x0+x1,m32); x1=ieor(tf_rotl32(x1,15),x0)
        x0=iand(x0+x1,m32); x1=ieor(tf_rotl32(x1,26),x0)
        x0=iand(x0+x1,m32); x1=ieor(tf_rotl32(x1,6),x0)
      else
        x0=iand(x0+x1,m32); x1=ieor(tf_rotl32(x1,17),x0)
        x0=iand(x0+x1,m32); x1=ieor(tf_rotl32(x1,29),x0)
        x0=iand(x0+x1,m32); x1=ieor(tf_rotl32(x1,16),x0)
        x0=iand(x0+x1,m32); x1=ieor(tf_rotl32(x1,24),x0)
      end if
      x0=iand(x0+ks(mod(i,3)),m32)
      x1=iand(x1+ks(mod(i+1,3))+int(i,i8),m32)
    end do

    o0=x0
    o1=x1

  end subroutine threefry2x32

end module threefry_mod
