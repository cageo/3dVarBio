subroutine bio_mod_ad

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
! Biological model                                                     !
!                                                                      !
! Version 1: A. Teruzzi 2018                                           !
!-----------------------------------------------------------------------

  use grd_str
  use bio_str
  use eof_str

  IMPLICIT NONE

  INTEGER(i4)     :: m, l, k, j, i
  
  grd%chl_ad(:,:,:) = 0.0

  do m=1,bio%ncmp
    do l=1,bio%nphy
      do k=1,grd%km
        do j=1,grd%jm
          do i=1,grd%im
            grd%chl_ad(i,j,k) = grd%chl_ad(i,j,k) + bio%cquot(i,j,k,l,m) * bio%pquot(i,j,k,l) * bio%phy_ad(i,j,k,l,m)
          enddo
        enddo
      enddo
    enddo
  enddo


end subroutine bio_mod_ad
