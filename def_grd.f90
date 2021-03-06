subroutine def_grd

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
  ! Define the grid                                                      !
  !                                                                      !
  ! Version 1: A. Teruzzi 2018                                           !
  !-----------------------------------------------------------------------


  use set_knd
  use drv_str
  use grd_str
  use mpi_str

  implicit none

  INTEGER(I4)    :: i, j, k
  INTEGER :: indSupWP
  ! ---
  ! Define grid

  ! Read grid definition
  call readGrid

  ! count the number of surface water points and index them
  nSurfaceWaterPoints = 0
  do i=1,grd%im
     do j=1,grd%jm
        if (grd%msk(i,j,1).eq.1) nSurfaceWaterPoints = nSurfaceWaterPoints+1
     enddo
  enddo


  ALLOCATE (SurfaceWaterPoints(2,nSurfaceWaterPoints))

  if(drv%Verbose .eq. 1) &
       write(*,*) 'nSurfaceWaterPoints = ', nSurfaceWaterPoints, 'of Rank ', MyId

  indSupWP=0
  do i=1,grd%im
     do j=1,grd%jm
        if (grd%msk(i,j,1).eq.1) then
           indSupWP = indSupWP+1
           SurfaceWaterPoints(1,indSupWP) = i
           SurfaceWaterPoints(2,indSupWP) = j
        endif
     enddo
  enddo

end subroutine def_grd
