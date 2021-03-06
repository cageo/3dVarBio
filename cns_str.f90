MODULE cns_str

!---------------------------------------------------------------------------
!                                                                          !
!    Copyright 2018 Anna Teruzzi, OGS, Trieste                         !
!                                                                          !
!    This file is part of 3DVarBio.
  !    3DVarBio is based on OceanVar (Dobricic, 2006)                                          !
!                                                                          !
!    3DVarBio is  free software: you can redistribute it and/or modify.     !
!    it under the terms of the GNU General Public License as published by  !
!    the Free Software Foundation, either version 3 of the License, or     !
!    (at your option) any later version.                                   !
!                                                                          !
!    3DVarBio is  distributed in the hope that it will be useful,           !
!    but WITHOUT ANY WARRANTY; without even the implied warranty of        !
!    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         !
!    GNU General Public License for more details.                          !
!                                                                          !
!    You should have received a copy of the GNU General Public License     !
!    along with OceanVar.  If not, see <http://www.gnu.org/licenses/>.       !
!                                                                          !
!---------------------------------------------------------------------------

!-----------------------------------------------------------------------
!                                                                      !
! Structure of constants                                               !
!                                                                      !
! Version 1: A. Teruzzi 2018                                           !
!-----------------------------------------------------------------------

 use set_knd

implicit none

public

   TYPE rcf_t

        INTEGER(i4)          ::  ntr     ! No. of iterations (half of)
        REAL(r8)             ::  dx      ! Grid resolution (m)
        REAL(r8)             ::  L       ! Correlation radius
!laura
        REAL(r8),POINTER     ::  Lxyz(:,:,:)!Correlation radius from file in km
        REAL(r8),POINTER     ::  L_x(:,:,:)!Correlation radius from file in km
        REAL(r8),POINTER     ::  L_y(:,:,:)!Correlation radius from file in km
        REAL(r8),POINTER     ::  rtx(:,:)!Correlation radius from file in km
        REAL(r8),POINTER     ::  rty(:,:)!Correlation radius from file in km
!laura
        REAL(r8)             ::  E       ! Norm
        REAL(r8)             ::  alp     ! Filter weight
        INTEGER(i4)          ::  ntb     ! Number of points in the table
        REAL(r8)             ::  dsmn    ! Minimum distance 
        REAL(r8)             ::  dsmx    ! Maximum distance 
        REAL(r8)             ::  dsl     ! Table increment
        REAL(r8), POINTER    ::  al(:)   ! Filter weights in the table
!laura
        REAL(r8), POINTER    ::  sc(:,:)   ! Filter scaling factors in the table
!laura
        REAL(r8)             ::  scl     ! Scaling factor
        REAL(r8)             ::  efc     ! Scaling factor for extended points
        INTEGER(i4)          ::  kstp    ! Step for extended points

   END TYPE rcf_t

   TYPE (rcf_t)              :: rcf

END MODULE cns_str
