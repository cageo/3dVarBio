subroutine def_nml

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
! Define analysis parameters from namelists                            !
!                                                                      !
! Version 1: S.Dobricic 2006                                           !
!-----------------------------------------------------------------------

  use set_knd
  use drv_str
  use grd_str
  use bmd_str
  use obs_str
  use eof_str
  use cns_str
  use ctl_str

  implicit none

  INTEGER(i4), PARAMETER    :: ngrids = 3

  CHARACTER(LEN=12) :: flag_a
  INTEGER(i4)   :: sdat_f, shou_f, lhou_f
  LOGICAL       :: read_eof
  INTEGER(i4)   :: neof, nreg, rcf_ntr, ntr
  INTEGER(i4)   :: ctl_m
  INTEGER(i4)   :: obs_sla, obs_arg, obs_xbt, obs_gld, obs_tra, obs_trd, obs_gvl, obs_chl
  INTEGER(i4)   :: obs_vdr, bmd_ncnt
  INTEGER(i4)   :: biol, bphy, nchl
  REAL(r8)      :: sla_dep, rcf_L, ctl_tol, ctl_per, bmd_fc1, bmd_fc2, rcf_efc, chl_dep
  REAL(r8)      :: bmd_dt, bmd_ndy, bmd_ady, bmd_alp, bmd_ovr, bmd_resem
  INTEGER(i4)   :: grid (ngrids)
  REAL(r8)      :: ratio(ngrids)
  INTEGER(i4)   :: mask (ngrids)
  INTEGER(i4)   :: barmd(ngrids)
  INTEGER(i4)   :: divda(ngrids)
  INTEGER(i4)   :: divdi(ngrids)
  LOGICAL       :: read_grd(ngrids)


  NAMELIST /runlst/ flag_a, sdat_f, shou_f, lhou_f
  NAMELIST /obslst/ obs_sla, obs_arg, obs_xbt, obs_gld, obs_tra, &
                    obs_trd, obs_vdr, obs_gvl, obs_chl
  NAMELIST /grdlst/ ntr, grid, read_grd, ratio, mask, barmd, divda, divdi
  NAMELIST /ctllst/ ctl_m, ctl_tol, ctl_per
  NAMELIST /covlst/ neof, nreg, read_eof, rcf_ntr, rcf_L, rcf_efc
  NAMELIST /slalst/ sla_dep
  NAMELIST /bmdlst/ bmd_dt, bmd_ndy, bmd_ady, bmd_alp, bmd_fc1, bmd_fc2,  &
                    bmd_ovr, bmd_resem, bmd_ncnt
  NAMELIST /biolst/ biol, bphy, nchl, chl_dep


! -------------------------------------------------------------------
! Open a formatted file for the diagnostics
! ---

  drv%dia = 12

  open ( drv%dia, file='OceanVar.diagnostics', form='formatted' )

!---------------------------------------------------------------------
! Open the namelist
! ---

  open(11,file='var_3d_nml',form='formatted')

  write(drv%dia,*) '------------------------------------------------------------'
  write(drv%dia,*) '  '
  write(drv%dia,*) '                      NAMELISTS: '
  write(drv%dia,*) '  '

! ---
  read(11,runlst)

  write(drv%dia,*) '------------------------------------------------------------'
  write(drv%dia,*) ' RUN NAMELIST INPUT: '
  write(drv%dia,*) ' Flag for the analysis:           flag_a   = ', flag_a
  write(drv%dia,*) ' Starting day of the forecast:    sdat_f   = ', sdat_f
  write(drv%dia,*) ' Starting hour of the forecast:   shou_f   = ', shou_f
  write(drv%dia,*) ' Lenght of the forecast:          lhou_f   = ', lhou_f

  drv%flag     = flag_a
  drv%sdat = sdat_f
  drv%shou = shou_f
  drv%lhou = lhou_f

! ---
  read(11,obslst)

  write(drv%dia,*) '------------------------------------------------------------'
  write(drv%dia,*) ' OBSERVATIONS NAMELIST INPUT: '
  write(drv%dia,*) ' Use SLA observations:                   obs_sla = ', obs_sla
  write(drv%dia,*) ' Use ARGO observations:                  obs_arg = ', obs_arg
  write(drv%dia,*) ' Use XBT observations:                   obs_xbt = ', obs_xbt
  write(drv%dia,*) ' Use glider observations:                obs_gld = ', obs_gld
  write(drv%dia,*) ' Use Argo trajectory observations:       obs_tra = ', obs_tra
  write(drv%dia,*) ' Use drifter trajectory observations:    obs_trd = ', obs_trd
  write(drv%dia,*) ' Use drifter observations of velocity:   obs_vdr = ', obs_vdr
  write(drv%dia,*) ' Use glider observations of velocity:    obs_gvl = ', obs_gvl
  write(drv%dia,*) ' Use Chlorophyll:                        obs_chl = ', obs_chl

    obs%sla = obs_sla
    obs%arg = obs_arg
    obs%xbt = obs_xbt
    obs%gld = obs_gld
    obs%tra = obs_tra
    obs%trd = obs_trd
    obs%vdr = obs_vdr
    obs%gvl = obs_gvl
    obs%chl = obs_chl

! ---
  read(11,grdlst)

  write(drv%dia,*) '------------------------------------------------------------'
  write(drv%dia,*) ' GRID NAMELIST INPUT: '
  write(drv%dia,*) ' Multigrid iterrations:                  ntr    = ', ntr
  write(drv%dia,*) ' Grids:                                 grid    = ', grid (1:ntr)
  write(drv%dia,*) ' Read grids from a file:               read_grd = ', read_grd
  write(drv%dia,*) ' Ratio:                                ratio    = ', ratio(1:ntr)
  write(drv%dia,*) ' Masks:                                 mask    = ',  mask(1:ntr)
  write(drv%dia,*) ' Run barotropic model:                 barmd    = ', barmd(1:ntr)
  write(drv%dia,*) ' Divergence damping in analysis:       divda    = ', divda(1:ntr)
  write(drv%dia,*) ' Divergence damping in initialisation: divdi    = ', divdi(1:ntr)

  drv%ntr = ntr
  ALLOCATE( drv%grid (drv%ntr))      ; drv%grid (1:drv%ntr)    = grid (1:drv%ntr)
  ALLOCATE( drv%read_grd (drv%ntr))  ; drv%read_grd(1:drv%ntr) = read_grd(1:drv%ntr)
  ALLOCATE( drv%ratco(drv%ntr))      ; drv%ratco(1:drv%ntr)    = ratio(1:drv%ntr)
  ALLOCATE( drv%ratio(drv%ntr))      ; drv%ratio               = huge(drv%ratio(1))
  ALLOCATE( drv%mask (drv%ntr))      ; drv%mask (1:drv%ntr)    = mask (1:drv%ntr)
  ALLOCATE( drv%bmd(drv%ntr))        ; drv%bmd  (1:drv%ntr)    = barmd(1:drv%ntr)
  ALLOCATE( drv%dda(drv%ntr))        ; drv%dda  (1:drv%ntr)    = divda(1:drv%ntr)
  ALLOCATE( drv%ddi(drv%ntr))        ; drv%ddi  (1:drv%ntr)    = divdi(1:drv%ntr)

  drv%ratio(        1)    = 1.0
  if(drv%ntr.gt.1) drv%ratio(2:drv%ntr)    = drv%ratco(1:drv%ntr-1) / drv%ratco(2:drv%ntr)

! ---
  read(11,ctllst)
  
  write(drv%dia,*) '------------------------------------------------------------'
  write(drv%dia,*) ' MINIMIZER NAMELIST INPUT: '
  write(drv%dia,*) ' Number of saved vectors:         ctl_m    = ', ctl_m
  write(drv%dia,*) ' Minimum gradient of J:           ctl_tol  = ', ctl_tol
  write(drv%dia,*) ' Percentage of initial gradient:  ctl_per  = ', ctl_per

       ctl%m     = ctl_m  
       ctl%pgtol = ctl_tol
       ctl%pgper = ctl_per

! ---
  read(11,covlst)
  
  write(drv%dia,*) '------------------------------------------------------------'
  write(drv%dia,*) ' COVARIANCE NAMELIST INPUT: '
  write(drv%dia,*) ' Number of EOFs:                  neof     = ', neof    
  write(drv%dia,*) ' Number of regions:               nreg     = ', nreg    
  write(drv%dia,*) ' Read EOFs from a file:           read_eof = ', read_eof
  write(drv%dia,*) ' Half number of iterations:       rcf_ntr  = ', rcf_ntr
  write(drv%dia,*) ' Horizontal correlation radius:   rcf_L    = ', rcf_L
  write(drv%dia,*) ' Extension factor for coastlines: rcf_efc  = ', rcf_efc

       ros%neof     = neof
       ros%nreg     = nreg
       ros%read_eof = read_eof
       rcf%ntr      = rcf_ntr
       rcf%L        = rcf_L
       rcf%efc      = rcf_efc

! ---
  read(11,slalst)

  write(drv%dia,*) '------------------------------------------------------------'
  write(drv%dia,*) ' SLA NAMELIST INPUT: '
  write(drv%dia,*) ' Minimum depth for observations:  sla_dep  = ', sla_dep

  sla%dep  = sla_dep

! ---
  read(11,bmdlst)

  write(drv%dia,*) '------------------------------------------------------------'
  write(drv%dia,*) ' BAROTROPIC MODEL NAMELIST INPUT: '
  write(drv%dia,*) ' Time step:           bmd_dt     = ', bmd_dt
  write(drv%dia,*) ' Simulation days:     bmd_ndy    = ', bmd_ndy
  write(drv%dia,*) ' Averaged days:       bmd_ady    = ', bmd_ady
  write(drv%dia,*) ' Implicit weight:     bmd_alp    = ', bmd_alp
  write(drv%dia,*) ' Friction intensity:  bmd_fc1    = ', bmd_fc1
  write(drv%dia,*) ' Friction intensity:  bmd_fc2    = ', bmd_fc2
  write(drv%dia,*) ' Over-relaxation:     bmd_ovr    = ', bmd_ovr
  write(drv%dia,*) ' Minimum residual:    bmd_resem  = ', bmd_resem
  write(drv%dia,*) ' Maximum iterations   bmd_ncnt   = ', bmd_ncnt 

  bmd%dt    = bmd_dt !7200. !1800.
  bmd%ndy   = bmd_ndy ! 3.
  bmd%ady   = bmd_ady ! 1.
  bmd%alp1  = bmd_alp !1.0
  bmd%fc1  = bmd_fc1
  bmd%fc2  = bmd_fc2
  bmd%ovr = bmd_ovr !1.9
  bmd%resem = bmd_resem !5.e-2
  bmd%ncnt = bmd_ncnt !201

  write(drv%dia,*) '------------------------------------------------------------'

! ---
  read(11,biolst)
  
  write(drv%dia,*) '------------------------------------------------------------'
  write(drv%dia,*) ' BIOLOGY NAMELIST INPUT: '
  write(drv%dia,*) ' Biological assimilation          biol     = ', biol    
  write(drv%dia,*) ' Biological+physical assimilation bphy     = ', bphy    
  write(drv%dia,*) ' Number of phytoplankton species  nchl     = ', nchl    
  write(drv%dia,*) ' Minimum depth for chlorophyll    chl_dep  = ', chl_dep

       drv%biol = biol
       drv%bphy = bphy
       grd%nchl = nchl
       chl%dep  = chl_dep



close(11)
end subroutine def_nml