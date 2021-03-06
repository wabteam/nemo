MODULE domain
   !!==============================================================================
   !!                       ***  MODULE domain   ***
   !! Ocean initialization : domain initialization
   !!==============================================================================

   !!----------------------------------------------------------------------
   !!   dom_init       : initialize the space and time domain
   !!   dom_nam        : read and contral domain namelists
   !!   dom_ctl        : control print for the ocean domain
   !!----------------------------------------------------------------------
   !! * Modules used
   USE oce             ! 
   USE dom_oce         ! ocean space and time domain
   USE phycst          ! physical constants
   USE in_out_manager  ! I/O manager
   USE lib_mpp         ! distributed memory computing library

   USE domstp          ! domain: set the time-step
   USE domrea          ! domain: write the meshmask file
   USE dommsk          ! domain : mask

   IMPLICIT NONE
   PRIVATE

   !! * Routine accessibility
   PUBLIC dom_init       ! called by opa.F90

   !! * Substitutions
#  include "domzgr_substitute.h90"
   !!----------------------------------------------------------------------
   !! NEMO/OFF 3.3 , NEMO Consortium (2010)
   !! $Id: domain.F90 3433 2012-07-19 07:29:05Z cetlod $
   !! Software governed by the CeCILL licence (NEMOGCM/NEMO_CeCILL.txt)
   !!----------------------------------------------------------------------

CONTAINS

   SUBROUTINE dom_init
      !!----------------------------------------------------------------------
      !!                  ***  ROUTINE dom_init  ***
      !!                    
      !! ** Purpose :   Domain initialization. Call the routines that are 
      !!      required to create the arrays which define the space and time
      !!      domain of the ocean model.
      !!
      !! ** Method  :
      !!      - dom_stp: defined the model time step
      !!      - dom_rea: read the meshmask file if nmsh=1
      !!
      !! History :
      !!        !  90-10  (C. Levy - G. Madec)  Original code
      !!        !  91-11  (G. Madec)
      !!        !  92-01  (M. Imbard) insert time step initialization
      !!        !  96-06  (G. Madec) generalized vertical coordinate 
      !!        !  97-02  (G. Madec) creation of domwri.F
      !!        !  01-05  (E.Durand - G. Madec) insert closed sea
      !!   8.5  !  02-08  (G. Madec)  F90: Free form and module
      !!----------------------------------------------------------------------
      !! * Local declarations
      INTEGER ::   iconf = 0         ! temporary integers
      !!----------------------------------------------------------------------

      IF(lwp) THEN
         WRITE(numout,*)
         WRITE(numout,*) 'dom_init : domain initialization'
         WRITE(numout,*) '~~~~~~~~'
      ENDIF

      CALL dom_nam      ! read namelist ( namrun, namdom, namcla )
      CALL dom_zgr      ! Vertical mesh and bathymetry option
      CALL dom_rea      ! Create a domain file
      CALL dom_stp      ! Time step
      CALL dom_msk      ! Masks
      CALL dom_ctl      ! Domain control

   END SUBROUTINE dom_init

   SUBROUTINE dom_nam
      !!----------------------------------------------------------------------
      !!                     ***  ROUTINE dom_nam  ***
      !!                    
      !! ** Purpose :   read domaine namelists and print the variables.
      !!
      !! ** input   : - namrun namelist
      !!              - namdom namelist
      !!              - namcla namelist
      !!----------------------------------------------------------------------
      USE ioipsl
      NAMELIST/namrun/ nn_no   , cn_exp    , cn_ocerst_in, cn_ocerst_out, ln_rstart , nn_rstctl,   &
         &             nn_it000, nn_itend  , nn_date0    , nn_leapy     , nn_istate , nn_stock ,   &
         &             nn_write, ln_dimgnnn, ln_mskland  , ln_clobber   , nn_chunksz
      NAMELIST/namdom/ nn_bathy , rn_e3zps_min, rn_e3zps_rat, nn_msh    , rn_hmin,     &
         &             nn_acc   , rn_atfp     , rn_rdt      , rn_rdtmin ,              &
         &             rn_rdtmax, rn_rdth     , nn_baro     , nn_closea
      NAMELIST/namcla/ nn_cla
#if defined key_netcdf4
      NAMELIST/namnc4/ nn_nchunks_i, nn_nchunks_j, nn_nchunks_k, ln_nc4zip
#endif
      !!----------------------------------------------------------------------

      REWIND( numnam )              ! Namelist namrun : parameters of the run
      READ  ( numnam, namrun )
      !
      IF(lwp) THEN                  ! control print
         WRITE(numout,*)
         WRITE(numout,*) 'dom_nam  : domain initialization through namelist read'
         WRITE(numout,*) '~~~~~~~ '
         WRITE(numout,*) '   Namelist namrun'  
         WRITE(numout,*) '      job number                      nn_no      = ', nn_no
         WRITE(numout,*) '      experiment name for output      cn_exp     = ', cn_exp
         WRITE(numout,*) '      restart logical                 ln_rstart  = ', ln_rstart
         WRITE(numout,*) '      control of time step            nn_rstctl  = ', nn_rstctl
         WRITE(numout,*) '      number of the first time step   nn_it000   = ', nn_it000
         WRITE(numout,*) '      number of the last time step    nn_itend   = ', nn_itend
         WRITE(numout,*) '      initial calendar date aammjj    nn_date0   = ', nn_date0
         WRITE(numout,*) '      leap year calendar (0/1)        nn_leapy   = ', nn_leapy
         WRITE(numout,*) '      initial state output            nn_istate  = ', nn_istate
         WRITE(numout,*) '      frequency of restart file       nn_stock   = ', nn_stock
         WRITE(numout,*) '      frequency of output file        nn_write   = ', nn_write
         WRITE(numout,*) '      multi file dimgout              ln_dimgnnn = ', ln_dimgnnn
         WRITE(numout,*) '      mask land points                ln_mskland = ', ln_mskland
         WRITE(numout,*) '      overwrite an existing file      ln_clobber = ', ln_clobber
         WRITE(numout,*) '      NetCDF chunksize (bytes)        nn_chunksz = ', nn_chunksz
      ENDIF
      no = nn_no                    ! conversion DOCTOR names into model names (this should disappear soon)
      cexper = cn_exp
      nrstdt = nn_rstctl
      nit000 = nn_it000
      nitend = nn_itend
      ndate0 = nn_date0
      nleapy = nn_leapy
      ninist = nn_istate
      nstock = nn_stock
      nwrite = nn_write


      !                             ! control of output frequency
      IF ( nstock == 0 .OR. nstock > nitend ) THEN
         WRITE(ctmp1,*) 'nstock = ', nstock, ' it is forced to ', nitend
         CALL ctl_warn( ctmp1 )
         nstock = nitend
      ENDIF
      IF ( nwrite == 0 ) THEN
         WRITE(ctmp1,*) 'nwrite = ', nwrite, ' it is forced to ', nitend
         CALL ctl_warn( ctmp1 )
         nwrite = nitend
      ENDIF

      ! parameters correspondting to nit000 - 1 (as we start the step loop with a call to day)
      ndastp = ndate0 - 1        ! ndate0 read in the namelist in dom_nam, we assume that we start run at 00:00
      adatrj = ( REAL( nit000-1, wp ) * rdttra(1) ) / rday

#if defined key_agrif
      IF( Agrif_Root() ) THEN
#endif
      SELECT CASE ( nleapy )        ! Choose calendar for IOIPSL
      CASE (  1 ) 
         CALL ioconf_calendar('gregorian')
         IF(lwp) WRITE(numout,*) '   The IOIPSL calendar is "gregorian", i.e. leap year'
      CASE (  0 )
         CALL ioconf_calendar('noleap')
         IF(lwp) WRITE(numout,*) '   The IOIPSL calendar is "noleap", i.e. no leap year'
      CASE ( 30 )
         CALL ioconf_calendar('360d')
         IF(lwp) WRITE(numout,*) '   The IOIPSL calendar is "360d", i.e. 360 days in a year'
      END SELECT
#if defined key_agrif
      ENDIF
#endif

      REWIND( numnam )             ! Domain
      READ  ( numnam, namdom )

      IF(lwp) THEN
         WRITE(numout,*) 
         WRITE(numout,*) '   Namelist namdom : space & time domain'
         WRITE(numout,*) '      flag read/compute bathymetry      nn_bathy     = ', nn_bathy
         WRITE(numout,*) '      min depth of the ocean    (>0) or    rn_hmin   = ', rn_hmin
         WRITE(numout,*) '      minimum thickness of partial      rn_e3zps_min = ', rn_e3zps_min, ' (m)'
         WRITE(numout,*) '         step level                     rn_e3zps_rat = ', rn_e3zps_rat
         WRITE(numout,*) '      create mesh/mask file(s)          nn_msh       = ', nn_msh
         WRITE(numout,*) '           = 0   no file created                 '
         WRITE(numout,*) '           = 1   mesh_mask                       '
         WRITE(numout,*) '           = 2   mesh and mask                   '
         WRITE(numout,*) '           = 3   mesh_hgr, msh_zgr and mask      '
         WRITE(numout,*) '      ocean time step                      rn_rdt    = ', rn_rdt
         WRITE(numout,*) '      asselin time filter parameter        rn_atfp   = ', rn_atfp
         WRITE(numout,*) '      time-splitting: nb of sub time-step  nn_baro   = ', nn_baro
         WRITE(numout,*) '      acceleration of converge             nn_acc    = ', nn_acc
         WRITE(numout,*) '        nn_acc=1: surface tracer rdt       rn_rdtmin = ', rn_rdtmin
         WRITE(numout,*) '                  bottom  tracer rdt       rdtmax    = ', rn_rdtmax
         WRITE(numout,*) '                  depth of transition      rn_rdth   = ', rn_rdth
         WRITE(numout,*) '      suppression of closed seas (=0)      nn_closea = ', nn_closea
      ENDIF

      ntopo     = nn_bathy          ! conversion DOCTOR names into model names (this should disappear soon)
      e3zps_min = rn_e3zps_min
      e3zps_rat = rn_e3zps_rat
      nmsh      = nn_msh
      nacc      = nn_acc
      atfp      = rn_atfp
      rdt       = rn_rdt
      rdtmin    = rn_rdtmin
      rdtmax    = rn_rdtmin
      rdth      = rn_rdth

      REWIND( numnam )             ! Namelist cross land advection
      READ  ( numnam, namcla )
      IF(lwp) THEN
         WRITE(numout,*)
         WRITE(numout,*) '   Namelist namcla'
         WRITE(numout,*) '      cross land advection                 nn_cla    = ', nn_cla
      ENDIF

#if defined key_netcdf4
      !                             ! NetCDF 4 case   ("key_netcdf4" defined)
      REWIND( numnam )                    ! Namelist namnc4 : netcdf4 chunking parameters
      READ  ( numnam, namnc4 )
      IF(lwp) THEN                        ! control print
         WRITE(numout,*)
         WRITE(numout,*) '   Namelist namnc4 - Netcdf4 chunking parameters'
         WRITE(numout,*) '      number of chunks in i-dimension      nn_nchunks_i   = ', nn_nchunks_i
         WRITE(numout,*) '      number of chunks in j-dimension      nn_nchunks_j   = ', nn_nchunks_j
         WRITE(numout,*) '      number of chunks in k-dimension      nn_nchunks_k   = ', nn_nchunks_k
         WRITE(numout,*) '      apply netcdf4/hdf5 chunking & compression ln_nc4zip = ', ln_nc4zip
      ENDIF

      ! Put the netcdf4 settings into a simple structure (snc4set, defined in in_out_manager module)
      ! Note the chunk size in the unlimited (time) dimension will be fixed at 1
      snc4set%ni   = nn_nchunks_i
      snc4set%nj   = nn_nchunks_j
      snc4set%nk   = nn_nchunks_k
      snc4set%luse = ln_nc4zip
#else
      snc4set%luse = .FALSE.        ! No NetCDF 4 case
#endif
      !
   END SUBROUTINE dom_nam

   SUBROUTINE dom_zgr
      !!----------------------------------------------------------------------
      !!                ***  ROUTINE dom_zgr  ***
      !!                   
      !! ** Purpose :  set the depth of model levels and the resulting 
      !!      vertical scale factors.
      !!
      !! ** Method  : - reference 1D vertical coordinate (gdep._0, e3._0)
      !!              - read/set ocean depth and ocean levels (bathy, mbathy)
      !!              - vertical coordinate (gdep., e3.) depending on the 
      !!                coordinate chosen :
      !!                   ln_zco=T   z-coordinate  
      !!                   ln_zps=T   z-coordinate with partial steps
      !!                   ln_zco=T   s-coordinate 
      !!
      !! ** Action  :   define gdep., e3., mbathy and bathy
      !!----------------------------------------------------------------------
      INTEGER ::   ioptio = 0   ! temporary integer
      !!
      NAMELIST/namzgr/ ln_zco, ln_zps, ln_sco
      !!----------------------------------------------------------------------

      REWIND ( numnam )                ! Read Namelist namzgr : vertical coordinate'
      READ   ( numnam, namzgr )

      IF(lwp) THEN                     ! Control print
         WRITE(numout,*)
         WRITE(numout,*) 'dom_zgr : vertical coordinate'
         WRITE(numout,*) '~~~~~~~'
         WRITE(numout,*) '          Namelist namzgr : set vertical coordinate'
         WRITE(numout,*) '             z-coordinate - full steps      ln_zco = ', ln_zco
         WRITE(numout,*) '             z-coordinate - partial steps   ln_zps = ', ln_zps
         WRITE(numout,*) '             s- or hybrid z-s-coordinate    ln_sco = ', ln_sco
      ENDIF

      ioptio = 0                       ! Check Vertical coordinate options
      IF( ln_zco ) ioptio = ioptio + 1
      IF( ln_zps ) ioptio = ioptio + 1
      IF( ln_sco ) ioptio = ioptio + 1
      IF ( ioptio /= 1 )   CALL ctl_stop( ' none or several vertical coordinate options used' )

   END SUBROUTINE dom_zgr

   SUBROUTINE dom_ctl
      !!----------------------------------------------------------------------
      !!                     ***  ROUTINE dom_ctl  ***
      !!
      !! ** Purpose :   Domain control.
      !!
      !! ** Method  :   compute and print extrema of masked scale factors
      !!
      !! History :
      !!   8.5  !  02-08  (G. Madec)    Original code
      !!----------------------------------------------------------------------
      !! * Local declarations
      INTEGER ::   iimi1, ijmi1, iimi2, ijmi2, iima1, ijma1, iima2, ijma2
      INTEGER, DIMENSION(2) ::   iloc      ! 
      REAL(wp) ::   ze1min, ze1max, ze2min, ze2max
      !!----------------------------------------------------------------------

      ! Extrema of the scale factors

      IF(lwp)WRITE(numout,*)
      IF(lwp)WRITE(numout,*) 'dom_ctl : extrema of the masked scale factors'
      IF(lwp)WRITE(numout,*) '~~~~~~~'

      IF (lk_mpp) THEN
         CALL mpp_minloc( e1t(:,:), tmask(:,:,1), ze1min, iimi1,ijmi1 )
         CALL mpp_minloc( e2t(:,:), tmask(:,:,1), ze2min, iimi2,ijmi2 )
         CALL mpp_maxloc( e1t(:,:), tmask(:,:,1), ze1max, iima1,ijma1 )
         CALL mpp_maxloc( e2t(:,:), tmask(:,:,1), ze2max, iima2,ijma2 )
      ELSE
         ze1min = MINVAL( e1t(:,:), mask = tmask(:,:,1) == 1.e0 )    
         ze2min = MINVAL( e2t(:,:), mask = tmask(:,:,1) == 1.e0 )    
         ze1max = MAXVAL( e1t(:,:), mask = tmask(:,:,1) == 1.e0 )    
         ze2max = MAXVAL( e2t(:,:), mask = tmask(:,:,1) == 1.e0 )    

         iloc  = MINLOC( e1t(:,:), mask = tmask(:,:,1) == 1.e0 )
         iimi1 = iloc(1) + nimpp - 1
         ijmi1 = iloc(2) + njmpp - 1
         iloc  = MINLOC( e2t(:,:), mask = tmask(:,:,1) == 1.e0 )
         iimi2 = iloc(1) + nimpp - 1
         ijmi2 = iloc(2) + njmpp - 1
         iloc  = MAXLOC( e1t(:,:), mask = tmask(:,:,1) == 1.e0 )
         iima1 = iloc(1) + nimpp - 1
         ijma1 = iloc(2) + njmpp - 1
         iloc  = MAXLOC( e2t(:,:), mask = tmask(:,:,1) == 1.e0 )
         iima2 = iloc(1) + nimpp - 1
         ijma2 = iloc(2) + njmpp - 1
      ENDIF

      IF(lwp) THEN
         WRITE(numout,"(14x,'e1t maxi: ',1f10.2,' at i = ',i5,' j= ',i5)") ze1max, iima1, ijma1
         WRITE(numout,"(14x,'e1t mini: ',1f10.2,' at i = ',i5,' j= ',i5)") ze1min, iimi1, ijmi1
         WRITE(numout,"(14x,'e2t maxi: ',1f10.2,' at i = ',i5,' j= ',i5)") ze2max, iima2, ijma2
         WRITE(numout,"(14x,'e2t mini: ',1f10.2,' at i = ',i5,' j= ',i5)") ze2min, iimi2, ijmi2
      ENDIF

   END SUBROUTINE dom_ctl

   !!======================================================================
END MODULE domain
