subroutine parallel_ver_hor
  
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
  ! Apply horizontal filter                                              !
  !                                                                      !
  ! Version 1: S.Dobricic 2006                                           !
  ! Version 2: S.Dobricic 2007                                           !
  !     Symmetric calculation in presence of coastal boundaries          !
  !     eta_ad, tem_ad, and sal_ad are here temporary arrays             !
  ! Version 3: A. Teruzzi 2013                                           !
  !     Attenuation of correction near the cost where d<200m             !
  !-----------------------------------------------------------------------
  
  
  use set_knd
  use grd_str
  use eof_str
  use cns_str
  use drv_str
  use obs_str
  use mpi_str

  implicit none
  
  INTEGER(i4)    :: i,j,k, ione, l
  INTEGER        :: jp,nestr
  REAL(r8)          :: chlapp(8),chlsum
  INTEGER(i4)    :: iProc, ierr
  REAL(r8), allocatable :: SendBuf4D(:,:,:,:), RecBuf4D(:,:,:,:), DefBuf4D(:,:,:,:)

  REAL(r8), POINTER    ::  ChlExtended(:,:,:,:)
  REAL(r8), POINTER    ::  SendLeft(:,:), RecRight(:,:)
  REAL(r8), POINTER    ::  SendRight(:,:), RecLeft(:,:)
  REAL(r8), POINTER    ::  SendTop(:,:), RecBottom(:,:)
  REAL(r8), POINTER    ::  SendBottom(:,:), RecTop(:,:)
  INTEGER   :: ReqRecvRight, ReqSendRight, ReqSendLeft, ReqRecvLeft
  INTEGER   :: ReqRecvTop, ReqSendTop, ReqSendBottom, ReqRecvBottom
  INTEGER   :: StatRight(MPI_STATUS_SIZE), StatLeft(MPI_STATUS_SIZE)
  INTEGER   :: StatTop(MPI_STATUS_SIZE), StatBottom(MPI_STATUS_SIZE)
  INTEGER   :: MyTag
  
  ALLOCATE(ChlExtended(0:grd%im+1, 0:grd%jm+1, grd%km, grd%nchl))
  ALLOCATE(SendLeft(grd%im, grd%km), RecRight(grd%im, grd%km))
  ALLOCATE(SendRight(grd%im, grd%km), RecLeft(grd%im, grd%km))
  ALLOCATE(SendTop(grd%jm, grd%km), RecTop(grd%jm, grd%km))
  ALLOCATE(SendBottom(grd%jm, grd%km), RecBottom(grd%jm, grd%km))
  

  ione = 1
  
  ! ---
  ! Vertical EOFs           
  call veof
  !return
  !goto 103 !No Vh
  
  ! ---
  ! Load temporary arrays
  if(drv%mask(drv%ktr) .gt. 1) then
     do l=1,grd%nchl
        !$OMP PARALLEL  &
        !$OMP PRIVATE(k)
        !$OMP DO
        do k=1,grd%km
           grd%chl_ad(:,:,k,l) = grd%chl(:,:,k,l) 
        enddo
        !$OMP END DO
        !$OMP END PARALLEL
     enddo
  endif
  

  ! **********************************************************************************
  !
  !                       NEW VERSION with ghost cells exchange
  !
  ! **********************************************************************************

  ! Filling array to send
  do k=1,grd%km
     do i=1,grd%im
        SendLeft(i,k)  = grd%chl(i,1,k,1)
        SendRight(i,k) = grd%chl(i,grd%jm,k,1)
     end do
     do j=1,grd%jm
        SendTop(j,k)  = grd%chl(1,j,k,1)
        SendBottom(j,k) = grd%chl(grd%im,j,k,1)
     end do     
  end do

  MyTag = 42
  RecRight(:,:)  = 0
  RecLeft(:,:)   = 0
  RecTop(:,:)    = 0
  RecBottom(:,:) = 0
  ChlExtended(:,:,:,:) = 0

  call MPI_Isend(SendLeft, grd%im*grd%km, MPI_REAL8, ProcLeft, MyTag, &
       MPI_COMM_WORLD, ReqSendLeft, ierr)
  call MPI_Irecv(RecRight, grd%im*grd%km, MPI_REAL8, ProcRight, MyTag, &
       MPI_COMM_WORLD, ReqRecvRight, ierr)

  call MPI_Isend(SendRight, grd%im*grd%km, MPI_REAL8, ProcRight, MyTag, &
       MPI_COMM_WORLD, ReqSendRight, ierr)
  call MPI_Irecv(RecLeft, grd%im*grd%km, MPI_REAL8, ProcLeft, MyTag, &
       MPI_COMM_WORLD, ReqRecvLeft, ierr)

  call MPI_Isend(SendTop, grd%jm*grd%km, MPI_REAL8, ProcTop, MyTag, &
       MPI_COMM_WORLD, ReqSendTop, ierr)
  call MPI_Irecv(RecBottom, grd%jm*grd%km, MPI_REAL8, ProcBottom, MyTag, &
       MPI_COMM_WORLD, ReqRecvBottom, ierr)

  call MPI_Isend(SendBottom, grd%jm*grd%km, MPI_REAL8, ProcBottom, MyTag, &
       MPI_COMM_WORLD, ReqSendBottom, ierr)
  call MPI_Irecv(RecTop, grd%jm*grd%km, MPI_REAL8, ProcTop, MyTag, &
       MPI_COMM_WORLD, ReqRecvTop, ierr)
  
  do k=1,grd%km
     do j=1,grd%jm
        do i=1,grd%im
           ChlExtended(i,j,k,1) = grd%chl(i,j,k,1)
        end do
     end do
  end do
  
  call MPI_Wait(ReqRecvRight, StatRight, ierr)
  call MPI_Wait(ReqRecvLeft, StatLeft, ierr)
  call MPI_Wait(ReqRecvTop, StatTop, ierr)
  call MPI_Wait(ReqRecvBottom, StatBottom, ierr)
  
  do k=1,grd%km
     do i=1,grd%im
        ChlExtended(i,grd%jm+1,k,1) = RecRight(i,k)
        ChlExtended(i,0,k,1) = RecLeft(i,k)
     end do
     do j=1,grd%jm
        ChlExtended(0,j,k,1) = RecTop(j,k)
        ChlExtended(grd%im+1,j,k,1) = RecBottom(j,k)
     end do
  end do

  !
  ! Attenuation of the correction near the cost and where d<200m 
  do l=1,grd%nchl
     do j=1,grd%jm
        do i=1,grd%im
           if ((grd%msk(i,j,chl%kdp).eq.0).and.  &
                (grd%msk(i,j,1).eq.1)) then
              do k=1,grd%km
                 if(grd%msk(i,j,k).eq.1) then
                    chlapp(1)=ChlExtended(i+1,j,  k,l)
                    chlapp(2)=ChlExtended(i-1,j,  k,l)
                    chlapp(3)=ChlExtended(i,  j+1,k,l)
                    chlapp(4)=ChlExtended(i,  j-1,k,l)
                    chlapp(5)=ChlExtended(i+1,j+1,k,l)
                    chlapp(6)=ChlExtended(i+1,j-1,k,l)
                    chlapp(7)=ChlExtended(i-1,j+1,k,l)
                    chlapp(8)=ChlExtended(i-1,j-1,k,l)
                    nestr=0
                    chlsum=0.
                    do jp=1,8
                       if ((chlapp(jp).ne.0).and.(chlapp(jp)/chlapp(jp).eq.1)) then
                          nestr=nestr+1;
                          chlsum=chlsum+chlapp(jp)
                       endif
                    enddo ! do on jp
                    if (nestr.ne.0) then
                       ChlExtended(i,j,k,l)=.1*chlsum/nestr
                    endif
                 endif !if on k
              enddo ! do on k
           endif ! if on grd%chl(i,j,1,l)
        enddo ! do on i
     enddo ! do on j
  enddo ! do on l

  do l=1,grd%nchl
     do k=1,grd%km
        do j=1,grd%jm
           do i=1,grd%im
              grd%chl(i,j,k,l) = ChlExtended(i,j,k,l)
           end do
        end do
     end do
  end do


  !********** APPLY RECURSIVE FILTERS ********** !

  ! ---
  ! x direction
  ALLOCATE(SendBuf4D(grd%nchl, grd%km, grd%im, grd%jm))
  ALLOCATE( RecBuf4D(grd%nchl, grd%km, grd%im, grd%jm))
  ALLOCATE( DefBuf4D(GlobalRow, localCol, grd%km, grd%nchl))
  
  do l=1,grd%nchl
     do k=1,grd%km
        do j=1,grd%jm
           do i=1,grd%im
              SendBuf4D(l,k,i,j) = grd%chl(i,j,k,l)
           end do
        end do
     end do
  end do
  
  call MPI_Alltoall(SendBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcI, MPI_REAL8, &
       RecBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcI, MPI_REAL8, RowCommunicator, ierr)

  do i=1,grd%im
     do iProc=0, NumProcI-1
        do j=1,localCol
           do k=1,grd%km
              DefBuf4D(i + iProc*localRow,j,k,1) = RecBuf4D(1,k,i,j + iProc*localCol)
           end do
        end do
     end do
  end do

  call rcfl_x( GlobalRow, localCol, grd%km*grd%nchl, grd%imax, grd%aex, grd%bex, DefBuf4D, grd%inx, grd%imx)

  do l=1,grd%nchl
     !$OMP PARALLEL  &
     !$OMP PRIVATE(k)
     !$OMP DO
     do k=1,grd%km
        DefBuf4D(:,:,k,l) = DefBuf4D(:,:,k,l) * grd%scx(:,:) 
     enddo
     !$OMP END DO
     !$OMP END PARALLEL
  enddo

  ! Reordering data to send back
  DEALLOCATE(SendBuf4D, RecBuf4D)
  ALLOCATE(SendBuf4D(grd%nchl, grd%km, localCol, GlobalRow))
  ALLOCATE( RecBuf4D(grd%nchl, grd%km, localCol, GlobalRow))

  do k=1,grd%km
     do j=1,localCol
        do i=1,GlobalRow
           SendBuf4D(1,k,j,i) = DefBuf4D(i,j,k,1)
        end do
     end do
  end do
  
  call MPI_Alltoall(SendBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcI, MPI_REAL8, &
       RecBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcI, MPI_REAL8, RowCommunicator, ierr)
  
  do i=1,grd%im
     do iProc=0, NumProcI-1
        do j=1,localCol
           do k=1,grd%km
              grd%chl(i,j + iProc*localCol,k,1) = RecBuf4D(1,k,j,i + iProc*localRow)
           end do
        end do
     end do
  end do
  
  ! ---
  ! y direction
  DEALLOCATE(SendBuf4D, RecBuf4D, DefBuf4D)
  ALLOCATE(SendBuf4D(grd%nchl, grd%km, grd%jm, grd%im))
  ALLOCATE( RecBuf4D(grd%nchl, grd%km, grd%jm, grd%im))
  ALLOCATE( DefBuf4D(localRow, GlobalCol, grd%km, grd%nchl))
  
  do l=1,grd%nchl
     do k=1,grd%km
        do j=1,grd%jm
           do i=1,grd%im
              SendBuf4D(l,k,j,i) = grd%chl(i,j,k,l)
           end do
        end do
     end do
  end do
  
  call MPI_Alltoall(SendBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcJ, MPI_REAL8, &
       RecBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcJ, MPI_REAL8, ColumnCommunicator, ierr)

  do i=1,localRow
     do iProc=0, NumProcJ-1
        do j=1,grd%jm
           do k=1,grd%km
              DefBuf4D(i,j + iProc*localCol,k,1) = RecBuf4D(1,k,j,i + iProc*localRow)
           end do
        end do
     end do
  end do

  ! Apply recursive filter in y direction
  call rcfl_y( localRow, GlobalCol, grd%km*grd%nchl, grd%jmax, grd%aey, grd%bey, DefBuf4D, grd%jnx, grd%jmx)

  ! ---
  ! Scale by the scaling factor
  do l=1,grd%nchl
     !$OMP PARALLEL  &
     !$OMP PRIVATE(k)
     !$OMP DO
     do k=1,grd%km
        DefBuf4D(:,:,k,l) = DefBuf4D(:,:,k,l) * grd%scy(:,:) 
     enddo
     !$OMP END DO
     !$OMP END PARALLEL
  enddo

  ! Reordering data to send back
  DEALLOCATE(SendBuf4D, RecBuf4D)
  ALLOCATE(SendBuf4D(grd%nchl, grd%km, localRow, GlobalCol))
  ALLOCATE( RecBuf4D(grd%nchl, grd%km, localRow, GlobalCol))
  
  do j=1,GlobalCol
     do i=1,localRow
        do k=1,grd%km
           SendBuf4D(1,k,i,j) = DefBuf4D(i,j,k,1)
        end do
     end do
  end do
  
  call MPI_Alltoall(SendBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcJ, MPI_REAL8, &
       RecBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcJ, MPI_REAL8, ColumnCommunicator, ierr)
  
  do i=1,localRow
     do iProc=0, NumProcJ-1
        do j=1,grd%jm
           do k=1,grd%km
              grd%chl(i + iProc*localRow,j,k,1) = RecBuf4D(1,k,i,j + iProc*localCol)
           end do
        end do
     end do
  end do

  
  ! ---
  ! Transpose calculation in the presense of coastal boundaries
  if(drv%mask(drv%ktr) .gt. 1) then
          
     ! ---
     ! y direction
     DEALLOCATE(SendBuf4D, RecBuf4D)
     ALLOCATE(SendBuf4D(grd%nchl, grd%km, grd%jm, grd%im))
     ALLOCATE( RecBuf4D(grd%nchl, grd%km, grd%jm, grd%im))
     
     do l=1,grd%nchl
        do k=1,grd%km
           do j=1,grd%jm
              do i=1,grd%im
                 SendBuf4D(l,k,j,i) = grd%chl_ad(i,j,k,l)
              end do
           end do
        end do
     end do
     
     call MPI_Alltoall(SendBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcJ, MPI_REAL8, &
          RecBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcJ, MPI_REAL8, ColumnCommunicator, ierr)
     
     do i=1,localRow
        do iProc=0, NumProcJ-1
           do j=1,grd%jm
              do k=1,grd%km
                 DefBuf4D(i,j + iProc*localCol,k,1) = RecBuf4D(1,k,j,i + iProc*localRow)
              end do
           end do
        end do
     end do
     
     ! ---
     ! Scale by the scaling factor
     do l=1,grd%nchl
        !$OMP PARALLEL  &
        !$OMP PRIVATE(k)
        !$OMP DO
        do k=1,grd%km
           DefBuf4D(:,:,k,l) = DefBuf4D(:,:,k,l) * grd%scy(:,:) 
        enddo
        !$OMP END DO
        !$OMP END PARALLEL
     enddo

     ! Apply recursive filter in y direction
     call rcfl_y_ad( localRow, GlobalCol, grd%km*grd%nchl, grd%jmax, grd%aey, grd%bey, DefBuf4D, grd%jnx, grd%jmx)
     
     ! Reordering data to send back
     DEALLOCATE(SendBuf4D, RecBuf4D)
     ALLOCATE(SendBuf4D(grd%nchl, grd%km, localRow, GlobalCol))
     ALLOCATE( RecBuf4D(grd%nchl, grd%km, localRow, GlobalCol))
     
     do j=1,GlobalCol
        do i=1,localRow
           do k=1,grd%km
              SendBuf4D(1,k,i,j) = DefBuf4D(i,j,k,1)
           end do
        end do
     end do
     
     call MPI_Alltoall(SendBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcJ, MPI_REAL8, &
          RecBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcJ, MPI_REAL8, ColumnCommunicator, ierr)
     
     do i=1,localRow
        do iProc=0, NumProcJ-1
           do j=1,grd%jm
              do k=1,grd%km
                 grd%chl_ad(i + iProc*localRow,j,k,1) = RecBuf4D(1,k,i,j + iProc*localCol)
              end do
           end do
        end do
     end do
     
     ! ---
     ! x direction
     DEALLOCATE(SendBuf4D, RecBuf4D, DefBuf4D)
     ALLOCATE(SendBuf4D(grd%nchl, grd%km, grd%im, grd%jm))
     ALLOCATE( RecBuf4D(grd%nchl, grd%km, grd%im, grd%jm))
     ALLOCATE( DefBuf4D(GlobalRow, localCol, grd%km, grd%nchl))
  
     do l=1,grd%nchl
        do k=1,grd%km
           do j=1,grd%jm
              do i=1,grd%im
                 SendBuf4D(l,k,i,j) = grd%chl_ad(i,j,k,l)
              end do
           end do
        end do
     end do
     
     call MPI_Alltoall(SendBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcI, MPI_REAL8, &
          RecBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcI, MPI_REAL8, RowCommunicator, ierr)
     
     do i=1,grd%im
        do iProc=0, NumProcI-1
           do j=1,localCol
              do k=1,grd%km
                 DefBuf4D(i + iProc*localRow,j,k,1) = RecBuf4D(1,k,i,j + iProc*localCol)
              end do
           end do
        end do
     end do
     
     ! ---
     ! Scale by the scaling factor
     do l=1,grd%nchl
        !$OMP PARALLEL  &
        !$OMP PRIVATE(k)
        !$OMP DO
        do k=1,grd%km
           DefBuf4D(:,:,k,l) = DefBuf4D(:,:,k,l) * grd%scx(:,:) 
        enddo
        !$OMP END DO
        !$OMP END PARALLEL
     enddo

     call rcfl_x_ad( GlobalRow, localCol, grd%km*grd%nchl, grd%imax, grd%aex, grd%bex, DefBuf4D, grd%inx, grd%imx)
     
     ! Reordering data to send back
     DEALLOCATE(SendBuf4D, RecBuf4D)
     ALLOCATE(SendBuf4D(grd%nchl, grd%km, localCol, GlobalRow))
     ALLOCATE( RecBuf4D(grd%nchl, grd%km, localCol, GlobalRow))

     do k=1,grd%km
        do j=1,localCol
           do i=1,GlobalRow
              SendBuf4D(1,k,j,i) = DefBuf4D(i,j,k,1)
           end do
        end do
     end do
     
     call MPI_Alltoall(SendBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcI, MPI_REAL8, &
          RecBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcI, MPI_REAL8, RowCommunicator, ierr)
     
     do i=1,grd%im
        do iProc=0, NumProcI-1
           do j=1,localCol
              do k=1,grd%km
                 grd%chl_ad(i,j + iProc*localCol,k,1) = RecBuf4D(1,k,j,i + iProc*localRow)
              end do
           end do
        end do
     end do
     
     
     ! ---
     ! Average
     do l=1,grd%nchl
        !$OMP PARALLEL  &
        !$OMP PRIVATE(k)
        !$OMP DO
        do k=1,grd%km
           grd%chl(:,:,k,l)   = (grd%chl(:,:,k,l) + grd%chl_ad(:,:,k,l) ) * 0.5 
        enddo
        !$OMP END DO
        !$OMP END PARALLEL
     enddo
     
  endif
  
  
  ! ---
  ! Scale for boundaries
  do l=1,grd%nchl
     !$OMP PARALLEL  &
     !$OMP PRIVATE(k)
     !$OMP DO
     do k=1,grd%km
        grd%chl(:,:,k,l)   = grd%chl(:,:,k,l) * grd%fct(:,:,k)  
     enddo
     !$OMP END DO
     !$OMP END PARALLEL
  enddo
  
  
  !103 continue
  ! Correction is zero out of mask (for correction near the coast)
  do k=1,grd%km
     do j=1,grd%jm
        do i=1,grd%im
           if (grd%msk(i,j,k).eq.0) then
              grd%chl(i,j,k,:) = 0.
           endif
        enddo  !i
     enddo  !j
  enddo  !k

  DEALLOCATE(SendBuf4D, RecBuf4D, DefBuf4D)
  DEALLOCATE(ChlExtended)
  DEALLOCATE(SendLeft, RecRight)
  DEALLOCATE(SendRight, RecLeft)
  DEALLOCATE(SendTop, RecBottom)
  DEALLOCATE(SendBottom, RecTop)

end subroutine parallel_ver_hor

subroutine parallel_ver_hor_ad
  
  !-----------------------------------------------------------------------
  !                                                                      !
  ! Transformation from physical to control space                        !
  !                                                                      !
  ! Version 1: S.Dobricic 2006                                           !
  ! Version 2: S.Dobricic 2007                                           !
  !     Symmetric calculation in presence of coastal boundaries          !
  !     eta, tem, and sal are here temporary arrays                      !
  ! Version 3: A.Teruzzi 2013                                            !
  !     Smoothing of the solution at d<200m                              !
  !-----------------------------------------------------------------------
  
  
  use set_knd
  use grd_str
  use eof_str
  use cns_str
  use drv_str
  use obs_str
  use mpi_str

  implicit none
  
  INTEGER(i4)    :: i,j,k, ione, l
  INTEGER        :: jp,nestr
  REAL(r8)       :: chlapp(8),chlsum
  INTEGER(i4)    :: iProc, ierr
  REAL(r8), allocatable :: SendBuf4D(:,:,:,:), RecBuf4D(:,:,:,:), DefBuf4D(:,:,:,:)
  
  REAL(r8), POINTER    ::  ChlExtended(:,:,:,:)
  REAL(r8), POINTER    ::  ChlExtendedAD(:,:,:,:)
  REAL(r8), POINTER    ::  SendLeft(:,:), RecRight(:,:)
  REAL(r8), POINTER    ::  SendRight(:,:), RecLeft(:,:)
  REAL(r8), POINTER    ::  SendTop(:,:), RecBottom(:,:)
  REAL(r8), POINTER    ::  SendBottom(:,:), RecTop(:,:)
  INTEGER   :: ReqRecvRight, ReqSendRight, ReqSendLeft, ReqRecvLeft
  INTEGER   :: ReqRecvTop, ReqSendTop, ReqSendBottom, ReqRecvBottom
  INTEGER   :: StatRight(MPI_STATUS_SIZE), StatLeft(MPI_STATUS_SIZE)
  INTEGER   :: StatTop(MPI_STATUS_SIZE), StatBottom(MPI_STATUS_SIZE)
  INTEGER   :: MyTag
  
  ! ---
  ! Correction is zero out of mask (for correction near the coast)
  do k=1,grd%km
     do j=1,grd%jm
        do i=1,grd%im
           if (grd%msk(i,j,k).eq.0) then
              grd%chl_ad(i,j,k,:) = 0.
           endif
        enddo  !i
     enddo  !j
  enddo  !k
  
  
  !goto 103 ! No Vh
  ione = 1
    
  ! ---
  ! Scale for boundaries
  do l=1,grd%nchl
     !$OMP PARALLEL  &
     !$OMP PRIVATE(k)
     !$OMP DO
     do k=1,grd%km
        grd%chl_ad(:,:,k,l)   = grd%chl_ad(:,:,k,l) * grd%fct(:,:,k) 
     enddo
     !$OMP END DO
     !$OMP END PARALLEL  
  enddo
    
  if(drv%mask(drv%ktr) .gt. 1) then
     
     ! ---
     ! Load temporary arrays
     do l=1,grd%nchl
        !$OMP PARALLEL  &
        !$OMP PRIVATE(k)
        !$OMP DO
        do k=1,grd%km
           grd%chl(:,:,k,l)    = grd%chl_ad(:,:,k,l) 
        enddo
        !$OMP END DO
        !$OMP END PARALLEL  
     enddo
     
     ! ---
     ! x direction
     ALLOCATE(SendBuf4D(grd%nchl, grd%km, grd%im, grd%jm))
     ALLOCATE( RecBuf4D(grd%nchl, grd%km, grd%im, grd%jm))
     ALLOCATE( DefBuf4D(GlobalRow, localCol, grd%km, grd%nchl))
     
     do l=1,grd%nchl
        do k=1,grd%km
           do j=1,grd%jm
              do i=1,grd%im
                 SendBuf4D(l,k,i,j) = grd%chl(i,j,k,l)
              end do
           end do
        end do
     end do
     
     call MPI_Alltoall(SendBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcI, MPI_REAL8, &
          RecBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcI, MPI_REAL8, RowCommunicator, ierr)
     
     do i=1,grd%im
        do iProc=0, NumProcI-1
           do j=1,localCol
              do k=1,grd%km
                 DefBuf4D(i + iProc*localRow,j,k,1) = RecBuf4D(1,k,i,j + iProc*localCol)
              end do
           end do
        end do
     end do
     
     call rcfl_x( GlobalRow, localCol, grd%km*grd%nchl, grd%imax, grd%aex, grd%bex, DefBuf4D, grd%inx, grd%imx)
     
     ! ---
     ! Scale by the scaling factor
     do l=1,grd%nchl
        !$OMP PARALLEL  &
        !$OMP PRIVATE(k)
        !$OMP DO
        do k=1,grd%km
           DefBuf4D(:,:,k,l) = DefBuf4D(:,:,k,l) * grd%scx(:,:) 
        enddo
        !$OMP END DO
        !$OMP END PARALLEL  
     enddo

     ! Reordering data to send back
     DEALLOCATE(SendBuf4D, RecBuf4D)
     ALLOCATE(SendBuf4D(grd%nchl, grd%km, localCol, GlobalRow))
     ALLOCATE( RecBuf4D(grd%nchl, grd%km, localCol, GlobalRow))
     
     do k=1,grd%km
        do j=1,localCol
           do i=1,GlobalRow
              SendBuf4D(1,k,j,i) = DefBuf4D(i,j,k,1)
           end do
        end do
     end do
     
     call MPI_Alltoall(SendBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcI, MPI_REAL8, &
          RecBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcI, MPI_REAL8, RowCommunicator, ierr)
     
     do i=1,grd%im
        do iProc=0, NumProcI-1
           do j=1,localCol
              do k=1,grd%km
                 grd%chl(i,j + iProc*localCol,k,1) = RecBuf4D(1,k,j,i + iProc*localRow)
              end do
           end do
        end do
     end do

     
     ! ---
     ! y direction
     DEALLOCATE(SendBuf4D, RecBuf4D, DefBuf4D)
     ALLOCATE(SendBuf4D(grd%nchl, grd%km, grd%jm, grd%im))
     ALLOCATE( RecBuf4D(grd%nchl, grd%km, grd%jm, grd%im))
     ALLOCATE( DefBuf4D(localRow, GlobalCol, grd%km, grd%nchl))
     
     do l=1,grd%nchl
        do k=1,grd%km
           do j=1,grd%jm
              do i=1,grd%im
                 SendBuf4D(l,k,j,i) = grd%chl(i,j,k,l)
              end do
           end do
        end do
     end do
     
     call MPI_Alltoall(SendBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcJ, MPI_REAL8, &
          RecBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcJ, MPI_REAL8, ColumnCommunicator, ierr)
     
     do i=1,localRow
        do iProc=0, NumProcJ-1
           do j=1,grd%jm
              do k=1,grd%km
                 DefBuf4D(i,j + iProc*localCol,k,1) = RecBuf4D(1,k,j,i + iProc*localRow)
              end do
           end do
        end do
     end do
     
     ! Apply recursive filter in y direction
     call rcfl_y( localRow, GlobalCol, grd%km*grd%nchl, grd%jmax, grd%aey, grd%bey, DefBuf4D, grd%jnx, grd%jmx)
     
     ! ---
     ! Scale by the scaling factor
     do l=1,grd%nchl
        !$OMP PARALLEL  &
        !$OMP PRIVATE(k)
        !$OMP DO
        do k=1,grd%km
           DefBuf4D(:,:,k,l) = DefBuf4D(:,:,k,l) * grd%scy(:,:) 
        enddo
        !$OMP END DO
        !$OMP END PARALLEL  
     enddo

     ! Reordering data to send back
     DEALLOCATE(SendBuf4D, RecBuf4D)
     ALLOCATE(SendBuf4D(grd%nchl, grd%km, localRow, GlobalCol))
     ALLOCATE( RecBuf4D(grd%nchl, grd%km, localRow, GlobalCol))
     
     do j=1,GlobalCol
        do i=1,localRow
           do k=1,grd%km
              SendBuf4D(1,k,i,j) = DefBuf4D(i,j,k,1)
           end do
        end do
     end do
     
     call MPI_Alltoall(SendBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcJ, MPI_REAL8, &
          RecBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcJ, MPI_REAL8, ColumnCommunicator, ierr)
     
     do i=1,localRow
        do iProc=0, NumProcJ-1
           do j=1,grd%jm
              do k=1,grd%km
                 grd%chl(i + iProc*localRow,j,k,1) = RecBuf4D(1,k,i,j + iProc*localCol)
              end do
           end do
        end do
     end do
     
  endif
    
  ! ---
  ! y direction
  DEALLOCATE(SendBuf4D, RecBuf4D)
  ALLOCATE(SendBuf4D(grd%nchl, grd%km, grd%jm, grd%im))
  ALLOCATE( RecBuf4D(grd%nchl, grd%km, grd%jm, grd%im))
  
  do l=1,grd%nchl
     do k=1,grd%km
        do j=1,grd%jm
           do i=1,grd%im
              SendBuf4D(l,k,j,i) = grd%chl_ad(i,j,k,l)
           end do
        end do
     end do
  end do
  
  call MPI_Alltoall(SendBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcJ, MPI_REAL8, &
       RecBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcJ, MPI_REAL8, ColumnCommunicator, ierr)
  
  do i=1,localRow
     do iProc=0, NumProcJ-1
        do j=1,grd%jm
           do k=1,grd%km
              DefBuf4D(i,j + iProc*localCol,k,1) = RecBuf4D(1,k,j,i + iProc*localRow)
           end do
        end do
     end do
  end do

  ! ---
  ! Scale by the scaling factor
  do l=1,grd%nchl
     !$OMP PARALLEL  &
     !$OMP PRIVATE(k)
     !$OMP DO
     do k=1,grd%km
        DefBuf4D(:,:,k,l) = DefBuf4D(:,:,k,l) * grd%scy(:,:) 
     enddo
     !$OMP END DO
     !$OMP END PARALLEL  
  enddo

  ! Apply recursive filter in y direction
  call rcfl_y_ad( localRow, GlobalCol, grd%km*grd%nchl, grd%jmax, grd%aey, grd%bey, DefBuf4D, grd%jnx, grd%jmx)

  ! Reordering data to send back
  DEALLOCATE(SendBuf4D, RecBuf4D)
  ALLOCATE(SendBuf4D(grd%nchl, grd%km, localRow, GlobalCol))
  ALLOCATE( RecBuf4D(grd%nchl, grd%km, localRow, GlobalCol))
  
  do j=1,GlobalCol
     do i=1,localRow
        do k=1,grd%km
           SendBuf4D(1,k,i,j) = DefBuf4D(i,j,k,1)
        end do
     end do
  end do
  
  call MPI_Alltoall(SendBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcJ, MPI_REAL8, &
       RecBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcJ, MPI_REAL8, ColumnCommunicator, ierr)
  
  do i=1,localRow
     do iProc=0, NumProcJ-1
        do j=1,grd%jm
           do k=1,grd%km
              grd%chl_ad(i + iProc*localRow,j,k,1) = RecBuf4D(1,k,i,j + iProc*localCol)
           end do
        end do
     end do
  end do
    
  
  ! ---
  ! x direction
  DEALLOCATE(SendBuf4D, RecBuf4D, DefBuf4D)
  ALLOCATE(SendBuf4D(grd%nchl, grd%km, grd%im, grd%jm))
  ALLOCATE( RecBuf4D(grd%nchl, grd%km, grd%im, grd%jm))
  ALLOCATE( DefBuf4D(GlobalRow, localCol, grd%km, grd%nchl))
  
  do l=1,grd%nchl
     do k=1,grd%km
        do j=1,grd%jm
           do i=1,grd%im
              SendBuf4D(l,k,i,j) = grd%chl_ad(i,j,k,l)
           end do
        end do
     end do
  end do
  
  call MPI_Alltoall(SendBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcI, MPI_REAL8, &
       RecBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcI, MPI_REAL8, RowCommunicator, ierr)
  
  do i=1,grd%im
     do iProc=0, NumProcI-1
        do j=1,localCol
           do k=1,grd%km
              DefBuf4D(i + iProc*localRow,j,k,1) = RecBuf4D(1,k,i,j + iProc*localCol)
           end do
        end do
     end do
  end do
  
  ! ---
  ! Scale by the scaling factor
  do l=1,grd%nchl
     !$OMP PARALLEL  &
     !$OMP PRIVATE(k)
     !$OMP DO
     do k=1,grd%km
        DefBuf4D(:,:,k,l) = DefBuf4D(:,:,k,l) * grd%scx(:,:) 
     enddo
     !$OMP END DO
     !$OMP END PARALLEL  
  enddo

  call rcfl_x_ad( GlobalRow, localCol, grd%km*grd%nchl, grd%imax, grd%aex, grd%bex, DefBuf4D, grd%inx, grd%imx)
  
  ! Reordering data to send back
  DEALLOCATE(SendBuf4D, RecBuf4D)
  ALLOCATE(SendBuf4D(grd%nchl, grd%km, localCol, GlobalRow))
  ALLOCATE( RecBuf4D(grd%nchl, grd%km, localCol, GlobalRow))
     
  do k=1,grd%km
     do j=1,localCol
        do i=1,GlobalRow
           SendBuf4D(1,k,j,i) = DefBuf4D(i,j,k,1)
        end do
     end do
  end do
  
  call MPI_Alltoall(SendBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcI, MPI_REAL8, &
       RecBuf4D, grd%nchl*grd%km*grd%jm*grd%im/NumProcI, MPI_REAL8, RowCommunicator, ierr)
  
  do i=1,grd%im
     do iProc=0, NumProcI-1
        do j=1,localCol
           do k=1,grd%km
              grd%chl_ad(i,j + iProc*localCol,k,1) = RecBuf4D(1,k,j,i + iProc*localRow)
           end do
        end do
     end do
  end do
  
  ! ---
  ! Average
  if(drv%mask(drv%ktr) .gt. 1) then
     do l=1,grd%nchl
        !$OMP PARALLEL  &
        !$OMP PRIVATE(k)
        !$OMP DO
        do k=1,grd%km
           grd%chl_ad(:,:,k,l)  = (grd%chl_ad(:,:,k,l) + grd%chl(:,:,k,l) ) * 0.5
        enddo
        !$OMP END DO
        !$OMP END PARALLEL  
     enddo
  endif
  
  
  
  ! **********************************************************************************
  !
  !                       NEW VERSION with ghost cells exchange
  !
  ! **********************************************************************************
  
  ALLOCATE(  ChlExtended(0:(grd%im+1), 0:(grd%jm+1), grd%km, grd%nchl))
  ALLOCATE(ChlExtendedAD(0:(grd%im+1), 0:(grd%jm+1), grd%km, grd%nchl))
  ALLOCATE(SendLeft(grd%im, grd%km), RecRight(grd%im, grd%km))
  ALLOCATE(SendRight(grd%im, grd%km), RecLeft(grd%im, grd%km))
  ALLOCATE(SendTop(grd%jm, grd%km), RecBottom(grd%jm, grd%km))
  ALLOCATE(SendBottom(grd%jm, grd%km), RecTop(grd%jm, grd%km))

  MyTag = 42
  RecRight(:,:)  = 0
  RecLeft(:,:)   = 0
  RecTop(:,:)    = 0
  RecBottom(:,:) = 0
  ChlExtended(:,:,:,:) = 0
  
  ! Filling array to send for ChlExtended
  do k=1,grd%km
     do i=1,grd%im
        SendLeft(i,k)  = grd%chl(i,1,k,1)
        SendRight(i,k) = grd%chl(i,grd%jm,k,1)
     end do
     do j=1,grd%jm
        SendTop(j,k)  = grd%chl(0,j,k,1)
        SendBottom(j,k) = grd%chl(grd%im,j,k,1)
     end do
  end do
  
  call MPI_Isend(SendLeft, grd%im*grd%km, MPI_REAL8, ProcLeft, MyTag, &
       MPI_COMM_WORLD, ReqSendLeft, ierr)
  call MPI_Irecv(RecRight, grd%im*grd%km, MPI_REAL8, ProcRight, MyTag, &
       MPI_COMM_WORLD, ReqRecvRight, ierr)

  call MPI_Isend(SendRight, grd%im*grd%km, MPI_REAL8, ProcRight, MyTag, &
       MPI_COMM_WORLD, ReqSendRight, ierr)
  call MPI_Irecv(RecLeft, grd%im*grd%km, MPI_REAL8, ProcLeft, MyTag, &
       MPI_COMM_WORLD, ReqRecvLeft, ierr)

  call MPI_Isend(SendTop, grd%jm*grd%km, MPI_REAL8, ProcTop, MyTag, &
       MPI_COMM_WORLD, ReqSendTop, ierr)
  call MPI_Irecv(RecBottom, grd%jm*grd%km, MPI_REAL8, ProcBottom, MyTag, &
       MPI_COMM_WORLD, ReqRecvBottom, ierr)

  call MPI_Isend(SendBottom, grd%jm*grd%km, MPI_REAL8, ProcBottom, MyTag, &
       MPI_COMM_WORLD, ReqSendBottom, ierr)
  call MPI_Irecv(RecTop, grd%jm*grd%km, MPI_REAL8, ProcTop, MyTag, &
       MPI_COMM_WORLD, ReqRecvTop, ierr)
  
  do k=1,grd%km
     do j=1,grd%jm
        do i=1,grd%im
           ChlExtended(i,j,k,1) = grd%chl(i,j,k,1)
        end do
     end do
  end do
  
  call MPI_Wait(ReqRecvRight, StatRight, ierr)
  call MPI_Wait(ReqRecvLeft, StatLeft, ierr)
  call MPI_Wait(ReqRecvTop, StatTop, ierr)
  call MPI_Wait(ReqRecvBottom, StatBottom, ierr)

  do k=1,grd%km
     do i=1,grd%im
        ChlExtended(i,grd%jm+1,k,1) = RecRight(i,k)
        ChlExtended(i,0,k,1) = RecLeft(i,k)
     end do
     do j=1,grd%jm
        ChlExtended(0,j,k,1) = RecTop(j,k)
        ChlExtended(grd%im+1,j,k,1) = RecBottom(j,k)
     end do
  end do

  ! Filling array to send for ChlExtendedAD
  do k=1,grd%km
     do i=1,grd%im
        SendLeft(i,k)  = grd%chl_ad(i,1,k,1)
        SendRight(i,k) = grd%chl_ad(i,grd%jm,k,1)
     end do
     do j=1,grd%jm
        SendTop(j,k)  = grd%chl_ad(1,j,k,1)
        SendBottom(j,k) = grd%chl_ad(grd%im,j,k,1)
     end do
  end do

  RecRight(:,:)  = 0
  RecLeft(:,:)   = 0
  RecTop(:,:)    = 0
  RecBottom(:,:) = 0
  ChlExtendedAD(:,:,:,:) = 0
  
  call MPI_Isend(SendLeft, grd%im*grd%km, MPI_REAL8, ProcLeft, MyTag, &
       MPI_COMM_WORLD, ReqSendLeft, ierr)
  call MPI_Irecv(RecRight, grd%im*grd%km, MPI_REAL8, ProcRight, MyTag, &
       MPI_COMM_WORLD, ReqRecvRight, ierr)

  call MPI_Isend(SendRight, grd%im*grd%km, MPI_REAL8, ProcRight, MyTag, &
       MPI_COMM_WORLD, ReqSendRight, ierr)
  call MPI_Irecv(RecLeft, grd%im*grd%km, MPI_REAL8, ProcLeft, MyTag, &
       MPI_COMM_WORLD, ReqRecvLeft, ierr)

  call MPI_Isend(SendTop, grd%jm*grd%km, MPI_REAL8, ProcTop, MyTag, &
       MPI_COMM_WORLD, ReqSendTop, ierr)
  call MPI_Irecv(RecBottom, grd%jm*grd%km, MPI_REAL8, ProcBottom, MyTag, &
       MPI_COMM_WORLD, ReqRecvBottom, ierr)

  call MPI_Isend(SendBottom, grd%jm*grd%km, MPI_REAL8, ProcBottom, MyTag, &
       MPI_COMM_WORLD, ReqSendBottom, ierr)
  call MPI_Irecv(RecTop, grd%jm*grd%km, MPI_REAL8, ProcTop, MyTag, &
       MPI_COMM_WORLD, ReqRecvTop, ierr)

  do k=1,grd%km
     do j=1,grd%jm
        do i=1,grd%im
           ChlExtendedAD(i,j,k,1) = grd%chl_ad(i,j,k,1)
        end do
     end do
  end do

  call MPI_Wait(ReqRecvRight, StatRight, ierr)
  call MPI_Wait(ReqRecvLeft, StatLeft, ierr)
  call MPI_Wait(ReqRecvTop, StatTop, ierr)
  call MPI_Wait(ReqRecvBottom, StatBottom, ierr)

  do k=1,grd%km
     do i=1,grd%im
        ChlExtendedAD(i,grd%jm+1,k,1) = RecRight(i,k)
        ChlExtendedAD(i,0,k,1) = RecLeft(i,k)
     end do
     do j=1,grd%jm
        ChlExtendedAD(0,j,k,1) = RecTop(j,k)
        ChlExtendedAD(grd%im+1,j,k,1) = RecBottom(j,k)
     end do
  end do


  !anna sreduction of correction d<200m
  do l=1,grd%nchl
     do j=1,grd%jm  ! OMP
        do i=1,grd%im
           if ((grd%msk(i,j,chl%kdp).eq.0).and.  &
                (grd%msk(i,j,1).eq.1)) then
              do k=1,grd%km
                 if(grd%msk(i,j,k).eq.1) then
                    chlapp(1)=ChlExtended(i+1,j,  k,l)
                    chlapp(2)=ChlExtended(i-1,j,  k,l)
                    chlapp(3)=ChlExtended(i,  j+1,k,l)
                    chlapp(4)=ChlExtended(i,  j-1,k,l)
                    chlapp(5)=ChlExtended(i+1,j+1,k,l)
                    chlapp(6)=ChlExtended(i+1,j-1,k,l)
                    chlapp(7)=ChlExtended(i-1,j+1,k,l)
                    chlapp(8)=ChlExtended(i-1,j-1,k,l)
                    nestr=0
                    do jp=1,8
                       if ((chlapp(jp).ne.0).and.(chlapp(jp)/chlapp(jp).eq.1)) then
                          nestr=nestr+1;
                       endif
                    enddo ! do on jp
                    if (nestr.ne.0) then
                       ChlExtendedAD(i+1,j,  k,l)=ChlExtendedAD(i+1,j,  k,l)+  &
                            .1*ChlExtendedAD(i,j,k,l)/nestr
                       ChlExtendedAD(i-1,j,  k,l)=ChlExtendedAD(i-1,j,  k,l)+  &
                            .1*ChlExtendedAD(i,j,k,l)/nestr
                       ChlExtendedAD(i,  j+1,k,l)=ChlExtendedAD(i  ,j+1,k,l)+  &
                            .1*ChlExtendedAD(i,j,k,l)/nestr
                       ChlExtendedAD(i,  j-1,k,l)=ChlExtendedAD(i  ,j-1,k,l)+  &
                            .1*ChlExtendedAD(i,j,k,l)/nestr
                       ChlExtendedAD(i+1,j+1,k,l)=ChlExtendedAD(i+1,j+1,k,l)+  &
                            .1*ChlExtendedAD(i,j,k,l)/nestr
                       ChlExtendedAD(i+1,j-1,k,l)=ChlExtendedAD(i+1,j-1,k,l)+  &
                            .1*ChlExtendedAD(i,j,k,l)/nestr
                       ChlExtendedAD(i-1,j+1,k,l)=ChlExtendedAD(i-1,j+1,k,l)+  &
                            .1*ChlExtendedAD(i,j,k,l)/nestr
                       ChlExtendedAD(i-1,j-1,k,l)=ChlExtendedAD(i-1,j-1,k,l)+  &
                            .1*ChlExtendedAD(i,j,k,l)/nestr
                       ChlExtendedAD(i,j,k,l)=0.
                    endif
                 endif !if on k
              enddo ! do on k
           endif ! if on grd%chl(i,j,1,l)
        enddo ! do on i
     enddo ! do on j
  enddo ! do on l

  do k=1,grd%km
     do j=1,grd%jm
        do i=1,grd%im
           grd%chl_ad(i,j,k,1) = ChlExtendedAD(i,j,k,1)
        end do
     end do
  end do


  !103 continue
  ! ---
  ! Vertical EOFs           
  call veof_ad

  DEALLOCATE(SendBuf4D, RecBuf4D, DefBuf4D)
  DEALLOCATE(ChlExtended, ChlExtendedAD)
  DEALLOCATE(SendLeft, RecRight)
  DEALLOCATE(SendRight, RecLeft)
  DEALLOCATE(SendTop, RecBottom)
  DEALLOCATE(SendBottom, RecTop)
  
end subroutine parallel_ver_hor_ad
