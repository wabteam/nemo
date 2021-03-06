MODULE dynldf_lap_tam
#ifdef key_tam
   !!======================================================================
   !!                       ***  MODULE  dynldf_lap_tam  ***
   !! Ocean dynamics:  lateral viscosity trend
   !!                  Tangent and Adjoint Module
   !!======================================================================
   !!----------------------------------------------------------------------
   !!   dyn_ldf_lap_tan  : update the momentum trend with the lateral diffusion
   !!                      using an iso-level harmonic operator (tangent)
   !!   dyn_ldf_lap_adj  : update the momentum trend with the lateral diffusion
   !!                      using an iso-level harmonic operator (adjoint)
   !!----------------------------------------------------------------------
   !! * Modules used
   USE par_oce
   USE oce_tam
   USE ldfdyn_oce
   USE dom_oce
   USE in_out_manager
   USE timing          ! Timing

   IMPLICIT NONE
   PRIVATE

   !! * Routine accessibility
   PUBLIC dyn_ldf_lap_tan  ! called by dynldf_tam.F90
   PUBLIC dyn_ldf_lap_adj  ! called by dynldf_tam.F90

   !! * Substitutions
#  include "domzgr_substitute.h90"
#  include "ldfdyn_substitute.h90"
#  include "vectopt_loop_substitute.h90"
   !!----------------------------------------------------------------------

CONTAINS

   SUBROUTINE dyn_ldf_lap_tan( kt )
      !!----------------------------------------------------------------------
      !!                     ***  ROUTINE dyn_ldf_lap_tan  ***
      !!
      !! ** Purpose of the direct routine:
      !!      Compute the before horizontal tracer (t & s) diffusive
      !!      trend and add it to the general trend of tracer equation.
      !!
      !! ** Method of the direct routine:
      !!      The before horizontal momentum diffusion trend is an
      !!      harmonic operator (laplacian type) which separates the divergent
      !!      and rotational parts of the flow.
      !!      Its horizontal components are computed as follow:
      !!         difu = 1/e1u di[ahmt hdivb] - 1/(e2u*e3u) dj-1[e3f ahmf rotb]
      !!         difv = 1/e2v dj[ahmt hdivb] + 1/(e1v*e3v) di-1[e3f ahmf rotb]
      !!      If lk_zco=T, e3f=e3u=e3v, the vertical scale factor are simplified
      !!      in the rotational part of the diffusion.
      !!      Add this before trend to the general trend (ua,va):
      !!            (ua,va) = (ua,va) + (diffu,diffv)
      !!      'key_trddyn' activated: the two components of the horizontal
      !!                                 diffusion trend are saved.
      !!
      !! ** Action : - Update (ua,va) with the before iso-level harmonic
      !!               mixing trend.
      !!
      !! History of the direct routine:
      !!        !  90-09 (G. Madec) Original code
      !!        !  91-11 (G. Madec)
      !!        !  96-01 (G. Madec) statement function for e3 and ahm
      !!   8.5  !  02-06 (G. Madec)  F90: Free form and module
      !!   9.0  !  04-08 (C. Talandier) New trends organization
      !! History of the tangent routine
      !!   9.0  !  08-08 (A. Vidard) tangent of 9.0
      !!   3.4  !  12-07 (P.-A. bouttier) Phasing with 3.4
      !!----------------------------------------------------------------------
      !! * Arguments
      INTEGER, INTENT( in ) ::   kt       ! ocean time-step index
      !! * Local declarations
      INTEGER  ::   ji, jj, jk            ! dummy loop indices
      REAL(wp) ::   &
         zuatl, zvatl, ze2utl, ze1vtl             ! temporary scalars
      !!----------------------------------------------------------------------
      !
      IF( nn_timing == 1 )  CALL timing_start('dyn_ldf_lap_tan')
      !
      IF( kt == nit000 ) THEN
         IF(lwp) WRITE(numout,*)
         IF(lwp) WRITE(numout,*) 'dyn_ldf_tan: iso-level harmonic (laplacien) operator'
         IF(lwp) WRITE(numout,*) '~~~~~~~~~~~ '
      ENDIF

      !                                                ! ===============
      DO jk = 1, jpkm1                                 ! Horizontal slab
         !                                             ! ===============
         DO jj = 2, jpjm1
            DO ji = fs_2, fs_jpim1   ! vector opt.
               ! horizontal diffusive trends
               ze2utl = rotb_tl (ji,jj,jk) * fsahmf(ji,jj,jk) * fse3f(ji,jj,jk)
               ze1vtl = hdivb_tl(ji,jj,jk) * fsahmt(ji,jj,jk)
               zuatl = - ( ze2utl - rotb_tl(ji  ,jj-1,jk) * fsahmf(ji  ,jj-1,jk) * fse3f(ji  ,jj-1,jk) ) &
                  &     / ( e2u(ji,jj) * fse3u(ji,jj,jk) )  &
                  &    + ( hdivb_tl(ji+1,jj  ,jk) * fsahmt(ji+1,jj  ,jk) - ze1vtl ) / e1u(ji,jj)

               zvatl = + ( ze2utl - rotb_tl(ji-1,jj  ,jk) * fsahmf(ji-1,jj  ,jk) * fse3f(ji-1,jj  ,jk) ) &
                  &     / ( e1v(ji,jj) * fse3v(ji,jj,jk) )  &
                  &    + ( hdivb_tl(ji  ,jj+1,jk) * fsahmt(ji  ,jj+1,jk) - ze1vtl ) / e2v(ji,jj)
               ! add it to the general momentum trends
               ua_tl(ji,jj,jk) = ua_tl(ji,jj,jk) + zuatl
               va_tl(ji,jj,jk) = va_tl(ji,jj,jk) + zvatl
            END DO
         END DO
         !                                             ! ===============
      END DO                                           !   End of slab
      !                                                ! ===============
      IF( nn_timing == 1 )  CALL timing_stop('dyn_ldf_lap_tan')
      !
   END SUBROUTINE dyn_ldf_lap_tan

   SUBROUTINE dyn_ldf_lap_adj( kt )
      !!----------------------------------------------------------------------
      !!                     ***  ROUTINE dyn_ldf_lap_adj  ***
      !!
      !! ** Purpose of the direct routine:
      !!      Compute the before horizontal tracer (t & s) diffusive
      !!      trend and add it to the general trend of tracer equation.
      !!
      !! ** Method of the direct routine:
      !!      The before horizontal momentum diffusion trend is an
      !!      harmonic operator (laplacian type) which separates the divergent
      !!      and rotational parts of the flow.
      !!      Its horizontal components are computed as follow:
      !!         difu = 1/e1u di[ahmt hdivb] - 1/(e2u*e3u) dj-1[e3f ahmf rotb]
      !!         difv = 1/e2v dj[ahmt hdivb] + 1/(e1v*e3v) di-1[e3f ahmf rotb]
      !!      If lk_zco=T, e3f=e3u=e3v, the vertical scale factor are simplified
      !!      in the rotational part of the diffusion.
      !!      Add this before trend to the general trend (ua,va):
      !!            (ua,va) = (ua,va) + (diffu,diffv)
      !!      'key_trddyn' activated: the two components of the horizontal
      !!                                 diffusion trend are saved.
      !!
      !! ** Action : - Update (ua,va) with the before iso-level harmonic
      !!               mixing trend.
      !!
      !! History of the direct routine:
      !!        !  90-09 (G. Madec) Original code
      !!        !  91-11 (G. Madec)
      !!        !  96-01 (G. Madec) statement function for e3 and ahm
      !!   8.5  !  02-06 (G. Madec)  F90: Free form and module
      !!   9.0  !  04-08 (C. Talandier) New trends organization
      !! History of the adjoint routine
      !!   9.0  !  08-08 (A. Vidard) adjoint of 9.0
      !!    -   !  09-01 (A. Weaver) misc. bug fixes and reorganization
      !!   3.4  !  12-07 (P.-A. bouttier) Phasing with 3.4
      !!----------------------------------------------------------------------
      !! * Arguments
      INTEGER, INTENT( in ) ::   kt       ! ocean time-step index
      !! * Local declarations
      INTEGER  ::   ji, jj, jk            ! dummy loop indices
      REAL(wp) ::   &
           zuaad , zvaad , ze2uad, ze1vad, &        ! temporary scalars
         & zuaad1, zvaad1, zuaad2, zvaad2           ! temporary scalars
      !!----------------------------------------------------------------------
      !
      IF( nn_timing == 1 )  CALL timing_start('dyn_ldf_lap_adj')
      !
      IF( kt == nitend ) THEN
         IF(lwp) WRITE(numout,*)
         IF(lwp) WRITE(numout,*) 'dyn_ldf_adj: iso-level harmonic (laplacien) operator'
         IF(lwp) WRITE(numout,*) '~~~~~~~~~~~ '
      ENDIF
      !                                                ! ===============
      DO jk = jpkm1, 1, -1                                ! Horizontal slab
         !                                             ! ===============
         DO jj = jpjm1, 2, -1
            DO ji = fs_jpim1, fs_2, -1   ! vector opt.
               ! add it to the general momentum trends
               zuaad = ua_ad(ji,jj,jk)
               zvaad = va_ad(ji,jj,jk)
               ! horizontal diffusive trends
               zvaad1 = zvaad /   e2v(ji,jj)
               zvaad2 = zvaad / ( e1v(ji,jj) * fse3v(ji,jj,jk) )
               zuaad1 = zuaad /   e1u(ji,jj)
               zuaad2 = zuaad / ( e2u(ji,jj) * fse3u(ji,jj,jk) )
               ze1vad = - zvaad1 - zuaad1
               ze2uad =   zvaad2 - zuaad2

               rotb_ad (ji-1,jj  ,jk) = rotb_ad (ji-1,jj  ,jk) &
                  &                   - zvaad2 * fsahmf(ji-1,jj  ,jk) * fse3f(ji-1,jj  ,jk)
               rotb_ad (ji  ,jj-1,jk) = rotb_ad (ji  ,jj-1,jk) &
                  &                   + zuaad2 * fsahmf(ji  ,jj-1,jk) * fse3f(ji  ,jj-1,jk)
               rotb_ad (ji  ,jj  ,jk) = rotb_ad (ji  ,jj  ,jk) &
                  &                   + ze2uad * fsahmf(ji  ,jj  ,jk) * fse3f(ji  ,jj  ,jk)

               hdivb_ad(ji  ,jj+1,jk) = hdivb_ad(ji  ,jj+1,jk) &
                  &                   + zvaad1 * fsahmt(ji  ,jj+1,jk)
               hdivb_ad(ji  ,jj  ,jk) = hdivb_ad(ji  ,jj  ,jk) &
                  &                   + ze1vad * fsahmt(ji  ,jj  ,jk)
               hdivb_ad(ji+1,jj  ,jk) = hdivb_ad(ji+1,jj  ,jk) &
                  &                   + zuaad1 * fsahmt(ji+1,jj  ,jk)
            END DO
         END DO
         !                                             ! ===============
      END DO                                           !   End of slab
      !                                                ! ===============
      IF( nn_timing == 1 )  CALL timing_stop('dyn_ldf_lap_adj')
      !
   END SUBROUTINE dyn_ldf_lap_adj

   !!======================================================================
#endif
END MODULE dynldf_lap_tam
