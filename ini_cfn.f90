subroutine ini_cfn
  
  !---------------------------------------------------------------------------
  !                                                                          !
  !    Copyright 2006 Srdjan Dobricic, CMCC, Bologna                         !
  !                                                                          !
  !    This file is part of OceanVar.                                          !
  !                                                                          !
  !    OceanVar is free software: you can redistribute it and/or modify.     !
  !    it under the terms of the GNU General Public License as published by  !
  !    the Free Software Foundation, either version 3 of the License, or     !
  !    (at your option) any later version.                                   !
  !                                                                          !
  !    OceanVar is distributed in the hope that it will be useful,           !
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
  ! Initialise the minimisation                                          !
  !                                                                      !
  ! Version 1: S.Dobricic 2006                                           !
  !-----------------------------------------------------------------------
  
  use set_knd
  use drv_str
  use obs_str
  use grd_str
  use eof_str
  use ctl_str
  use mpi_str
  
  implicit none
  
  INTEGER(i4)  :: i, ierr
  
  ! ---
  ! Allocate memory for optimization arrays

  ctl%n = nSurfaceWaterPoints * ros%neof
  call MPI_Allreduce(ctl%n, ctl%n_global, 1, MPI_INT, MPI_SUM, Var3DCommunicator, ierr)

  if (MyId .eq. 0) write(drv%dia,*) 'size of the control vector: ',ctl%n_global


  ALLOCATE( ctl%x_c(ctl%n)) ; ctl%x_c = huge(ctl%x_c(1))
  ALLOCATE( ctl%g_c(ctl%n)) ; ctl%g_c = huge(ctl%g_c(1))

     
  do i=1,ctl%n
    ctl%x_c(i)= 0.0d0
  enddo
     
  ctl%f_c = 0.0
  
end subroutine ini_cfn
