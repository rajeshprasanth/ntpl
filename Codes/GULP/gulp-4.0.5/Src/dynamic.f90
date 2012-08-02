  subroutine dynamic(nkp)
!
!  Master routine for generating phased second derivatives
!  On diagonal block elements (i,i) for element i can no longer be
!  generated by summing off diagonals. Therefore these elements
!  are retained from the normal second derivative matrix and
!  added in afterwards in phonon.
!
!  nkp    = number of k point to be calculated by this call
!
!   8/95 Molecule fixing option added
!   3/97 Modified so that only a single K point can be
!        calculated on each call for simplicity
!   5/97 Sutton-Chen potential modifications added. Note that the
!        bulk rho values should be set before calling dynamic
!        from the previous function call.
!   8/97 Geometry set up removed as should never be needed as
!        call to phonon will be preceeded by call to energy.
!   4/01 Calculation of phase factor moved into dynamic from
!        lower level routines.
!   4/01 Modified to allow the option for K points to be specified
!        with reference to the full centred unit cell
!   5/02 Electrostatic contribution for polymers completed
!   8/02 Brenner potential added
!  11/02 Einstein model added
!  11/03 Bond order potential added
!   9/04 Call to bond order charge derivatives added
!   7/06 Sixbody contribution added
!   4/09 Separate call to generate MEAM densities added
!   6/09 Module name changed from three to m_three
!   9/10 Neutron scattering modifications added
!
!  Conditions of use:
!
!  GULP is available free of charge to academic institutions
!  and non-commerical establishments only. Copies should be
!  obtained from the author only and should not be distributed
!  in any form by the user to a third party without the express
!  permission of the author. This notice applies to all parts
!  of the program, except any library routines which are
!  distributed with the code for completeness. All rights for
!  such routines remain with the original distributor.
!
!  No claim is made that this program is free from errors and
!  no liability will be accepted for any loss or damage that
!  may result. The user is responsible for checking the validity
!  of their results.
!
!  Copyright Curtin University 2010
!
!  Julian Gale, NRI, Curtin University, September 2010
!
  use bondorderdata, only : nbopot, nboQ, nboQ0
  use control
  use current
  use derivatives
  use eam,           only : lMEAMden, maxmeamcomponent
  use four
  use ksample
  use ksample_scatter
  use scatterdata,   only : lscattercall
  use six
  use sutton
  use m_three
  implicit none
!
!  Passed variables
!
  integer(i4), intent(in)                   :: nkp
!
!  Local variables
!
  integer(i4)                               :: i
  integer(i4)                               :: j
  integer(i4)                               :: maxlim
  integer(i4)                               :: mint
  real(dp)                                  :: ebondorder
  real(dp)                                  :: eboQself
  real(dp)                                  :: ebrenner
  real(dp)                                  :: eeinstein
  real(dp)                                  :: kvf(3,3)
  real(dp)                                  :: xk
  real(dp)                                  :: yk
  real(dp)                                  :: zk
  real(dp)                                  :: xkv
  real(dp)                                  :: ykv
  real(dp)                                  :: zkv
!**********************************************
!  EEM/QEq calculation of charge derivatives  *
!**********************************************
  if (leem) then
    call dcharge(.false.,.true.,.false.)
  endif
!*************************************************
!  Bond Order calculation of charge derivatives  *
!*************************************************
  if (nboQ.gt.0) then
    call getBOcharge(.true.,.true.)
  endif
!****************************
!  Zero second derivatives  *
!****************************
  mint = 3*numat
  maxlim = mint
  if (nbsmat.gt.0) maxlim = maxlim + numat
  if (maxlim.gt.maxd2u) then
    maxd2u = maxlim
    call changemaxd2
  endif
  if (maxlim.gt.maxd2) then
    maxd2 = maxlim
    call changemaxd2
  endif
  do i = 1,maxlim
    do j = 1,maxlim
      derv2(j,i) = 0.0_dp
      dervi(j,i) = 0.0_dp
    enddo
  enddo
!
!  Select appropriate K vectors
!
  if (lkfull.and.ndim.eq.3) then
    call kvector3Df(kvf)
  else
    kvf(1:3,1:3) = kv(1:3,1:3)
  endif
!***************************
!  Calculate phase factor  *
!***************************
  if (lscattercall) then
    xk = xskpt(nkp)
    yk = yskpt(nkp)
    zk = zskpt(nkp)
  else
    xk = xkpt(nkp)
    yk = ykpt(nkp)
    zk = zkpt(nkp)
  endif
  if (ndim.eq.3) then
    xkv = xk*kvf(1,1) + yk*kvf(1,2) + zk*kvf(1,3)
    ykv = xk*kvf(2,1) + yk*kvf(2,2) + zk*kvf(2,3)
    zkv = xk*kvf(3,1) + yk*kvf(3,2) + zk*kvf(3,3)
  elseif (ndim.eq.2) then
    xkv = xk*kvf(1,1) + yk*kvf(1,2)
    ykv = xk*kvf(2,1) + yk*kvf(2,2)
    zkv = 0.0_dp
  elseif (ndim.eq.1) then
    xkv = xk*kvf(1,1)
    ykv = 0.0_dp
    zkv = 0.0_dp
  endif
!*******************************
!  Reciprocal space component  *
!*******************************
  if (lewald.and.ndim.gt.1) then
    call kindex
    if (ndim.eq.3) then
      call recip3Dp(xkv,ykv,zkv)
    elseif (ndim.eq.2) then
      call recip2Dp(xkv,ykv)
    endif
  endif
!*************************
!  Real space component  *
!*************************
  call realp(xkv,ykv,zkv)
  if (ndim.eq.1) call real1Dp(xkv)
!**********************************
!  Bond order charge self-energy  *
!**********************************
  if (nboQ0.gt.0) then
    call BOself(eboQself,.true.,.true.,.true.)
  endif
!*************************
!  Three-body component  *
!*************************
  if (nthb.gt.0) call threep(xkv,ykv,zkv)
!************************
!  Four-body component  *
!************************
  if (nfor.gt.0) call fourp(xkv,ykv,zkv)
!***********************
!  Six-body component  *
!***********************
  if (nsix.gt.0) call sixp(xkv,ykv,zkv)
!************************
!  Many-body component  *
!************************
  if (lsuttonc) then
    if (lMEAMden) then
      call density3
    endif
    call manyp(xkv,ykv,zkv)
  endif
!**********************
!  Brenner potential  *
!**********************
  if (lbrenner) then
    ebrenner = 0.0_dp
    call brenner(ebrenner,xkv,ykv,zkv,.true.,.true.,.true.)
  endif
!************************
!  Bondorder potential  *
!************************
  if (nbopot.gt.0) then
    ebondorder = 0.0_dp
    call bondorder(ebondorder,xkv,ykv,zkv,.true.,.true.,.true.)
  endif
!*****************************
!  Einstein model component  *
!*****************************
  if (leinstein) then
    eeinstein = 0.0_dp
    call einstein(eeinstein,.true.,.true.)
  endif
!
  return
  end
