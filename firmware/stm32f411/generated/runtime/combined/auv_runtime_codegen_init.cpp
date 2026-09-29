//
// Academic License - for use in teaching, academic research, and meeting
// course requirements at degree granting institutions only.  Not for
// government, commercial, or other organizational use.
// File: auv_runtime_codegen_init.cpp
//
// MATLAB Coder version            : 25.2
// C/C++ source code generated on  : 28-Aug-2026 17:25:48
//

// Include Files
#include "auv_runtime_codegen_init.h"
#include "auv_runtime_codegen_init_types.h"
#include "rt_nonfinite.h"
#include "rt_defines.h"
#include <algorithm>
#include <cmath>
#include <cstring>

// Type Definitions
struct struct_T {
  double yaw_ref;
  double pitch_ref;
  double u_ref;
  double psi;
  double theta;
  double r;
  double q;
  double u;
  double r_ff;
  double pitch_ref_dot;
  double phi;
  double w;
  double p;
};

struct b_struct_T {
  double delta_r;
  double delta_e;
  double thrust;
};

struct c_struct_T {
  double p[3];
  double v[3];
  double q[4];
  double bg[3];
  double ba[3];
  double c[3];
  double Pdiag[18];
  double euler[3];
  double vel_body_water[3];
  bool initialized;
  bool valid;
  unsigned int health_bits;
};

struct d_struct_T {
  unsigned char state;
  bool all_aid_fresh;
  double age[7];
  bool fresh[7];
  double tau_fresh[7];
  unsigned int health_bits;
};

struct e_struct_T {
  double residual;
  bool anomaly_latched;
  unsigned int health_bits;
};

// Function Declarations
static bool all_finite18(const double x[18]);

static bool all_finite18x18(const double A[324]);

static bool all_finite3(const double x[3]);

static bool all_finite4(const double x[4]);

static bool avail_freshness(double params_tol_time,
                            const bool params_present[7],
                            const double params_tau_fresh[7],
                            const double state_last_accept_t[7],
                            const bool state_have_accept[7],
                            double state_init_time, double t, double age[7],
                            bool fresh[7], bool &af);

static bool avail_out_is_finite(const double out_age[7],
                                const double out_tau_fresh[7]);

static bool avail_state_is_finite(double state_deg_timer,
                                  double state_loss_timer,
                                  double state_posok_timer,
                                  double state_allok_timer,
                                  const double state_last_accept_t[7],
                                  double state_init_time, double state_last_t);

static void availability_codegen_step(
    double params_T_degrade, double params_T_lost, double params_T_reacq,
    double params_T_clear, double params_T_settle, double params_tol_time,
    const bool params_present[7], const double params_tau_fresh[7],
    bool params_config_valid, struct13_T &state, double in_t, bool in_init_done,
    const bool in_accepted[7], d_struct_T &out);

static bool chol3_spd(const double A[9]);

namespace coder {
static double b_atan2(double y, double x);

static double b_dot(const double a[2], const double b[2]);

static void b_eye(double b_I[324]);

static double b_hypot(double x, double y);

static double b_mod(double x, double y);

static double b_norm(const double x[3]);

static double c_norm(const double x[2]);

static double dot(const double a[3], const double b[3]);

static void eye(double b_I[9]);

namespace internal {
namespace scalar {
static double c_mod(double x);

}
} // namespace internal
static double interp1(const double varargin_1[4], const double varargin_2[4],
                      double varargin_3);

static void wrapToPi(double &lambda);

} // namespace coder
static b_struct_T controller_codegen_step(const struct1_T &params,
                                          struct10_T &state,
                                          const struct_T &in);

static double guidance_codegen_step(
    const double pos[3], const double path_pad[96], double n_path,
    double progress_index, double u_body, double v_body, double U_h,
    double zdot_inertial, double theta_phys, const struct2_T &cfg,
    struct11_T &state, double &pitch_ref, double &u_ref,
    double &next_progress_index, double &r_ff, double &pitch_ref_dot);

static bool inv3_fixed(const double A[9], double Ainv[9]);

static void nav_codegen_step(const struct6_T &params, struct12_T &state,
                             const struct16_T &in, c_struct_T &out);

static void nav_fill_out(bool state_initialized, const double state_p[3],
                         const double state_v[3], const double state_q[4],
                         const double state_bg[3], const double state_ba[3],
                         const double state_c[3], const double state_P[324],
                         bool valid, unsigned int hb, c_struct_T &out);

static unsigned int
nav_op_initialize(double params_g_ned, const double params_P0_p[3],
                  double params_P0_p_abs, const double params_P0_v[3],
                  const double params_P0_th[3], const double params_P0_bg[3],
                  const double params_P0_ba[3], const double params_P0_c[3],
                  double params_tol_pair, struct12_T &state,
                  const struct16_T &in, bool &valid);

static unsigned int nav_op_propagate(
    double params_g_ned, double params_sigma_p, double params_sigma_a,
    double params_sigma_g, double params_sigma_bg, double params_sigma_ba,
    double params_sigma_c, double params_dt_prop_max, double params_dt_prop_sub,
    double params_n_sub_max, double params_tol_time, double params_tol_pair,
    struct12_T &state, const struct16_T &in, bool &valid);

static unsigned int nav_op_update(
    double params_R_depth, double params_R_heading,
    const double params_R_ins[3], const double params_R_dvl[3],
    const double params_R_usbl[3], double params_lat_depth,
    double params_lat_heading, double params_lat_ins, double params_lat_dvl,
    double params_lat_usbl, double params_q_min_frac, double params_q_floor,
    double params_nis_scale, double params_tol_time, struct12_T &state,
    const struct16_T &in, bool &valid, bool &fused);

static bool
nav_state_is_finite(const double state_p[3], const double state_v[3],
                    const double state_q[4], const double state_bg[3],
                    const double state_ba[3], const double state_c[3],
                    const double state_P[324], const double state_last_ts[7],
                    const double state_last_accept_t[7]);

static bool path_is_valid(const double path_pad[96], double n_path);

static void path_unpad(const double path_pad[96], double path_mat[96]);

static double project_interval_fixed(const double p[3], const double path[96],
                                     const double s_nodes[32], double n,
                                     double s_lo, double s_hi, double &d_best);

static void quat2rot_local(const double q[4], double R[9]);

static void quat_from_rotvec_local(const double v[3], double q[4]);

static void quat_mul_local(const double a[4], const double b[4], double q[4]);

static void quat_norm_local(double q[4]);

static void rot2euler_local(const double R[9], double e[3]);

static double rt_roundd_snf(double u);

static e_struct_T rudder_fdir_codegen_step(
    double params_G_nom, double params_thr_B2, double params_eps_dr_rad,
    double params_u_floor, double params_t_warmup_s, double params_Np,
    bool params_config_valid, struct14_T &state, double in_t,
    double in_delta_r_cmd, double in_r, double in_u, bool in_sample_valid,
    unsigned int in_seq);

static void sample_path_fixed(const double path[96], const double s_nodes[32],
                              double n, double s, bool is_closed, double p[3],
                              double t_hat[3]);

static void skew_local(const double v[3], double S[9]);

// Function Definitions
//
// Arguments    : const double x[18]
// Return Type  : bool
//
static bool all_finite18(const double x[18])
{
  bool ok;
  ok = true;
  for (int i{0}; i < 18; i++) {
    double d;
    d = x[i];
    ok = ((!std::isinf(d)) && (!std::isnan(d)) && ok);
  }
  return ok;
}

//
// Arguments    : const double A[324]
// Return Type  : bool
//
static bool all_finite18x18(const double A[324])
{
  bool ok;
  ok = true;
  for (int i{0}; i < 18; i++) {
    for (int j{0}; j < 18; j++) {
      double d;
      d = A[i + 18 * j];
      ok = ((!std::isinf(d)) && (!std::isnan(d)) && ok);
    }
  }
  return ok;
}

//
// Arguments    : const double x[3]
// Return Type  : bool
//
static bool all_finite3(const double x[3])
{
  bool ok;
  if ((!std::isinf(x[0])) && (!std::isnan(x[0])) &&
      ((!std::isinf(x[1])) && (!std::isnan(x[1]))) &&
      ((!std::isinf(x[2])) && (!std::isnan(x[2])))) {
    ok = true;
  } else {
    ok = false;
  }
  return ok;
}

//
// Arguments    : const double x[4]
// Return Type  : bool
//
static bool all_finite4(const double x[4])
{
  bool ok;
  if ((!std::isinf(x[0])) && (!std::isnan(x[0])) &&
      ((!std::isinf(x[1])) && (!std::isnan(x[1]))) &&
      ((!std::isinf(x[2])) && (!std::isnan(x[2]))) &&
      ((!std::isinf(x[3])) && (!std::isnan(x[3])))) {
    ok = true;
  } else {
    ok = false;
  }
  return ok;
}

//
// Arguments    : double params_tol_time
//                const bool params_present[7]
//                const double params_tau_fresh[7]
//                const double state_last_accept_t[7]
//                const bool state_have_accept[7]
//                double state_init_time
//                double t
//                double age[7]
//                bool fresh[7]
//                bool &af
// Return Type  : bool
//
static bool avail_freshness(double params_tol_time,
                            const bool params_present[7],
                            const double params_tau_fresh[7],
                            const double state_last_accept_t[7],
                            const bool state_have_accept[7],
                            double state_init_time, double t, double age[7],
                            bool fresh[7], bool &af)
{
  bool pf;
  bool saw;
  for (int i{0}; i < 7; i++) {
    double ref;
    if (state_have_accept[i]) {
      ref = state_last_accept_t[i];
    } else {
      ref = state_init_time;
    }
    ref = t - ref;
    age[i] = ref;
    fresh[i] = (ref <= params_tau_fresh[i] + params_tol_time);
  }
  pf = false;
  if (params_present[5]) {
    pf = fresh[5];
  }
  if (params_present[6]) {
    pf = (fresh[6] || pf);
  }
  af = true;
  saw = false;
  for (int i{0}; i < 5; i++) {
    if (params_present[i + 2]) {
      saw = true;
      af = (fresh[i + 2] && af);
    }
  }
  af = (saw && af);
  return pf;
}

//
// Arguments    : const double out_age[7]
//                const double out_tau_fresh[7]
// Return Type  : bool
//
static bool avail_out_is_finite(const double out_age[7],
                                const double out_tau_fresh[7])
{
  bool ok;
  if ((!std::isinf(out_age[0])) && (!std::isnan(out_age[0])) &&
      ((!std::isinf(out_age[1])) && (!std::isnan(out_age[1]))) &&
      ((!std::isinf(out_age[2])) && (!std::isnan(out_age[2]))) &&
      ((!std::isinf(out_age[3])) && (!std::isnan(out_age[3]))) &&
      ((!std::isinf(out_age[4])) && (!std::isnan(out_age[4]))) &&
      ((!std::isinf(out_age[5])) && (!std::isnan(out_age[5]))) &&
      ((!std::isinf(out_age[6])) && (!std::isnan(out_age[6]))) &&
      ((!std::isinf(out_tau_fresh[0])) && (!std::isnan(out_tau_fresh[0]))) &&
      ((!std::isinf(out_tau_fresh[1])) && (!std::isnan(out_tau_fresh[1]))) &&
      ((!std::isinf(out_tau_fresh[2])) && (!std::isnan(out_tau_fresh[2]))) &&
      ((!std::isinf(out_tau_fresh[3])) && (!std::isnan(out_tau_fresh[3]))) &&
      ((!std::isinf(out_tau_fresh[4])) && (!std::isnan(out_tau_fresh[4]))) &&
      ((!std::isinf(out_tau_fresh[5])) && (!std::isnan(out_tau_fresh[5]))) &&
      ((!std::isinf(out_tau_fresh[6])) && (!std::isnan(out_tau_fresh[6])))) {
    ok = true;
  } else {
    ok = false;
  }
  return ok;
}

//
// Arguments    : double state_deg_timer
//                double state_loss_timer
//                double state_posok_timer
//                double state_allok_timer
//                const double state_last_accept_t[7]
//                double state_init_time
//                double state_last_t
// Return Type  : bool
//
static bool avail_state_is_finite(double state_deg_timer,
                                  double state_loss_timer,
                                  double state_posok_timer,
                                  double state_allok_timer,
                                  const double state_last_accept_t[7],
                                  double state_init_time, double state_last_t)
{
  bool ok;
  if ((!std::isinf(state_deg_timer)) && (!std::isnan(state_deg_timer)) &&
      ((!std::isinf(state_loss_timer)) && (!std::isnan(state_loss_timer))) &&
      ((!std::isinf(state_posok_timer)) && (!std::isnan(state_posok_timer))) &&
      ((!std::isinf(state_allok_timer)) && (!std::isnan(state_allok_timer))) &&
      ((!std::isinf(state_init_time)) && (!std::isnan(state_init_time))) &&
      ((!std::isinf(state_last_t)) && (!std::isnan(state_last_t))) &&
      ((!std::isinf(state_last_accept_t[0])) &&
       (!std::isnan(state_last_accept_t[0]))) &&
      ((!std::isinf(state_last_accept_t[1])) &&
       (!std::isnan(state_last_accept_t[1]))) &&
      ((!std::isinf(state_last_accept_t[2])) &&
       (!std::isnan(state_last_accept_t[2]))) &&
      ((!std::isinf(state_last_accept_t[3])) &&
       (!std::isnan(state_last_accept_t[3]))) &&
      ((!std::isinf(state_last_accept_t[4])) &&
       (!std::isnan(state_last_accept_t[4]))) &&
      ((!std::isinf(state_last_accept_t[5])) &&
       (!std::isnan(state_last_accept_t[5]))) &&
      ((!std::isinf(state_last_accept_t[6])) &&
       (!std::isnan(state_last_accept_t[6])))) {
    ok = true;
  } else {
    ok = false;
  }
  return ok;
}

//
// AVAILABILITY_CODEGEN_STEP Explicit-state Gate 5C availability step (fixed
// ABI).
//  DEPLOY_CANDIDATE / HEALTH_STATUS_ONLY / NOT_IN_PRODUCTION / NOT_CERTIFIED
//  Isolated health-only runtime. No estimator mutation, no actuator authority.
//
//  Codes: 0 UNINITIALIZED, 1 NOMINAL, 2 DEGRADED, 3 POSITION_AID_LOST, 4
//  RECOVERING. Channels: 1 gyro, 2 accel, 3 depth, 4 heading, 5 INS vel, 6 DVL,
//  7 USBL. Required aids: present channels 3:7. Position aids: present channels
//  6:7.
//
//  health_bits uint32: 1 CONFIG_INVALID, 2 INPUT_NONFINITE, 4
//  TIME_NONINCREASING, 8 NO_REQUIRED_AID, 16 STATE_NONFINITE. Nonzero =>
//  fail-silent, hold prior. Corrupt nonfinite state cold-recovers and emits
//  bit 16.
//
//  Authority flags are compile-time false: accommodation_requested,
//  filter_reset_requested, abort_requested.
//
//  TASK_ID: AVAILABILITY_RUNTIME_001
//
// Arguments    : double params_T_degrade
//                double params_T_lost
//                double params_T_reacq
//                double params_T_clear
//                double params_T_settle
//                double params_tol_time
//                const bool params_present[7]
//                const double params_tau_fresh[7]
//                bool params_config_valid
//                struct13_T &state
//                double in_t
//                bool in_init_done
//                const bool in_accepted[7]
//                d_struct_T &out
// Return Type  : void
//
static void availability_codegen_step(
    double params_T_degrade, double params_T_lost, double params_T_reacq,
    double params_T_clear, double params_T_settle, double params_tol_time,
    const bool params_present[7], const double params_tau_fresh[7],
    bool params_config_valid, struct13_T &state, double in_t, bool in_init_done,
    const bool in_accepted[7], d_struct_T &out)
{
  unsigned int hb;
  if (!avail_state_is_finite(state.deg_timer, state.loss_timer,
                             state.posok_timer, state.allok_timer,
                             state.last_accept_t, state.init_time,
                             state.last_t)) {
    state.code = 0U;
    state.deg_timer = 0.0;
    state.loss_timer = 0.0;
    state.posok_timer = 0.0;
    state.allok_timer = 0.0;
    state.init_time = 0.0;
    state.last_t = 0.0;
    state.have_init = false;
    state.have_t = false;
    state.trans_count = 0U;
    state.trans_from = 0U;
    state.trans_to = 0U;
    out.state = 0U;
    out.all_aid_fresh = false;
    for (int i{0}; i < 7; i++) {
      state.last_accept_t[i] = 0.0;
      state.have_accept[i] = false;
      if ((!std::isinf(params_tau_fresh[i])) &&
          (!std::isnan(params_tau_fresh[i]))) {
        out.tau_fresh[i] = params_tau_fresh[i];
      } else {
        out.tau_fresh[i] = 0.0;
      }
      out.age[i] = 0.0;
      out.fresh[i] = false;
    }
    out.health_bits = 16U;
  } else {
    double age[7];
    bool do_step;
    bool guard1;
    out.fresh[0] = in_accepted[0];
    out.fresh[1] = in_accepted[1];
    out.fresh[2] = in_accepted[2];
    out.fresh[3] = in_accepted[3];
    out.fresh[4] = in_accepted[4];
    out.fresh[5] = in_accepted[5];
    out.fresh[6] = in_accepted[6];
    do_step = false;
    guard1 = false;
    if (!params_config_valid) {
      hb = 1U;
      guard1 = true;
    } else if (std::isinf(in_t) || std::isnan(in_t)) {
      hb = 2U;
      guard1 = true;
    } else if (state.have_init && (!(in_t > state.last_t))) {
      hb = 4U;
      guard1 = true;
    } else {
      bool ok;
      ok = false;
      for (int i{0}; i < 5; i++) {
        ok = (params_present[i + 2] || ok);
      }
      if ((!ok) && (in_init_done || state.have_init)) {
        hb = 8U;
        guard1 = true;
      } else {
        if (state.have_init || in_init_done) {
          do_step = true;
        }
        if (do_step) {
          double dt;
          unsigned char prev;
          if (!state.have_init) {
            state.have_init = true;
            state.init_time = in_t;
            state.code = 1U;
            dt = 0.0;
          } else {
            dt = in_t - state.last_t;
          }
          state.last_t = in_t;
          state.have_t = true;
          for (int i{0}; i < 7; i++) {
            if (out.fresh[i]) {
              state.last_accept_t[i] = in_t;
              state.have_accept[i] = true;
            }
          }
          ok =
              avail_freshness(params_tol_time, params_present, params_tau_fresh,
                              state.last_accept_t, state.have_accept,
                              state.init_time, in_t, age, out.fresh, do_step);
          if (ok) {
            state.loss_timer = 0.0;
            state.posok_timer += dt;
          } else {
            state.loss_timer += dt;
            state.posok_timer = 0.0;
          }
          if (do_step) {
            state.allok_timer += dt;
            state.deg_timer = 0.0;
          } else {
            state.allok_timer = 0.0;
            state.deg_timer += dt;
          }
          prev = state.code;
          if (state.code == 1) {
            if (state.deg_timer >= params_T_degrade - params_tol_time) {
              state.code = 2U;
            }
          } else if (state.code == 2) {
            if (state.loss_timer >= params_T_lost - params_tol_time) {
              state.code = 3U;
            } else if (state.allok_timer >= params_T_clear - params_tol_time) {
              state.code = 1U;
            }
          } else if (state.code == 3) {
            if (state.posok_timer >= params_T_reacq - params_tol_time) {
              state.code = 4U;
            }
          } else if (state.code == 4) {
            if (state.loss_timer >= params_T_lost - params_tol_time) {
              state.code = 3U;
            } else if (state.allok_timer >= params_T_settle - params_tol_time) {
              state.code = 1U;
            }
          }
          if (state.code != prev) {
            unsigned int qY;
            hb = state.trans_count;
            qY = hb + 1U;
            if (hb + 1U < hb) {
              qY = MAX_uint32_T;
            }
            state.trans_count = qY;
            state.trans_from = prev;
            state.trans_to = state.code;
          }
          if (!avail_state_is_finite(state.deg_timer, state.loss_timer,
                                     state.posok_timer, state.allok_timer,
                                     state.last_accept_t, state.init_time,
                                     state.last_t)) {
            state.code = 0U;
            state.deg_timer = 0.0;
            state.loss_timer = 0.0;
            state.posok_timer = 0.0;
            state.allok_timer = 0.0;
            state.init_time = 0.0;
            state.last_t = 0.0;
            state.have_init = false;
            state.have_t = false;
            state.trans_count = 0U;
            state.trans_from = 0U;
            state.trans_to = 0U;
            out.state = 0U;
            out.all_aid_fresh = false;
            for (int i{0}; i < 7; i++) {
              state.last_accept_t[i] = 0.0;
              state.have_accept[i] = false;
              if ((!std::isinf(params_tau_fresh[i])) &&
                  (!std::isnan(params_tau_fresh[i]))) {
                out.tau_fresh[i] = params_tau_fresh[i];
              } else {
                out.tau_fresh[i] = 0.0;
              }
              out.age[i] = 0.0;
              out.fresh[i] = false;
            }
            out.health_bits = 16U;
          } else {
            for (int i{0}; i < 7; i++) {
              if ((!std::isinf(params_tau_fresh[i])) &&
                  (!std::isnan(params_tau_fresh[i]))) {
                out.tau_fresh[i] = params_tau_fresh[i];
              } else {
                out.tau_fresh[i] = 0.0;
              }
              if ((!std::isinf(age[i])) && (!std::isnan(age[i]))) {
                out.age[i] = age[i];
              } else {
                out.age[i] = 0.0;
              }
            }
            out.state = state.code;
            out.all_aid_fresh = do_step;
            out.health_bits = 0U;
          }
        } else {
          out.state = state.code;
          out.all_aid_fresh = false;
          for (int i{0}; i < 7; i++) {
            if ((!std::isinf(params_tau_fresh[i])) &&
                (!std::isnan(params_tau_fresh[i]))) {
              out.tau_fresh[i] = params_tau_fresh[i];
            } else {
              out.tau_fresh[i] = 0.0;
            }
            out.age[i] = 0.0;
            out.fresh[i] = false;
          }
          out.health_bits = 0U;
        }
      }
    }
    if (guard1) {
      if (state.have_init &&
          ((!std::isinf(state.last_t)) && (!std::isnan(state.last_t)))) {
        avail_freshness(params_tol_time, params_present, params_tau_fresh,
                        state.last_accept_t, state.have_accept, state.init_time,
                        state.last_t, age, out.fresh, out.all_aid_fresh);
      } else {
        for (int i{0}; i < 7; i++) {
          age[i] = 0.0;
          out.fresh[i] = false;
        }
        out.all_aid_fresh = false;
      }
      for (int i{0}; i < 7; i++) {
        if ((!std::isinf(params_tau_fresh[i])) &&
            (!std::isnan(params_tau_fresh[i]))) {
          out.tau_fresh[i] = params_tau_fresh[i];
        } else {
          out.tau_fresh[i] = 0.0;
        }
        if ((!std::isinf(age[i])) && (!std::isnan(age[i]))) {
          out.age[i] = age[i];
        } else {
          out.age[i] = 0.0;
        }
      }
      out.state = state.code;
      out.health_bits = hb;
    }
    if (!avail_out_is_finite(out.age, out.tau_fresh)) {
      state.code = 0U;
      state.deg_timer = 0.0;
      state.loss_timer = 0.0;
      state.posok_timer = 0.0;
      state.allok_timer = 0.0;
      state.init_time = 0.0;
      state.last_t = 0.0;
      state.have_init = false;
      state.have_t = false;
      state.trans_count = 0U;
      state.trans_from = 0U;
      state.trans_to = 0U;
      out.state = 0U;
      out.all_aid_fresh = false;
      for (int i{0}; i < 7; i++) {
        state.last_accept_t[i] = 0.0;
        state.have_accept[i] = false;
        if ((!std::isinf(params_tau_fresh[i])) &&
            (!std::isnan(params_tau_fresh[i]))) {
          out.tau_fresh[i] = params_tau_fresh[i];
        } else {
          out.tau_fresh[i] = 0.0;
        }
        out.age[i] = 0.0;
        out.fresh[i] = false;
      }
      out.health_bits = 16U;
    }
  }
}

//
// Arguments    : const double A[9]
// Return Type  : bool
//
static bool chol3_spd(const double A[9])
{
  bool ok;
  ok = false;
  if ((!std::isinf(A[0])) && (!std::isnan(A[0])) &&
      ((!std::isinf(A[1])) && (!std::isnan(A[1]))) &&
      ((!std::isinf(A[2])) && (!std::isnan(A[2]))) &&
      ((!std::isinf(A[4])) && (!std::isnan(A[4]))) &&
      ((!std::isinf(A[5])) && (!std::isnan(A[5]))) &&
      ((!std::isinf(A[8])) && (!std::isnan(A[8]))) &&
      ((!std::isinf(A[3])) && (!std::isnan(A[3]))) &&
      ((!std::isinf(A[6])) && (!std::isnan(A[6]))) &&
      ((!std::isinf(A[7])) && (!std::isnan(A[7]))) && (!(A[0] <= 1.0E-18))) {
    double l11;
    double l21;
    double l31;
    double t22;
    l11 = std::sqrt(A[0]);
    l21 = A[1] / l11;
    l31 = A[2] / l11;
    t22 = A[4] - l21 * l21;
    if ((!std::isinf(t22)) && (!std::isnan(t22)) && (t22 > 1.0E-18)) {
      double l32;
      double t33;
      t22 = std::sqrt(t22);
      l32 = (A[5] - l31 * l21) / t22;
      t33 = (A[8] - l31 * l31) - l32 * l32;
      if ((!std::isinf(l11)) && (!std::isnan(l11)) &&
          ((!std::isinf(l21)) && (!std::isnan(l21))) &&
          ((!std::isinf(l31)) && (!std::isnan(l31))) && (!std::isinf(t22)) &&
          ((!std::isinf(l32)) && (!std::isnan(l32))) &&
          ((!std::isinf(t33)) && (!std::isnan(t33))) && (t33 > 1.0E-18)) {
        ok = !std::isinf(std::sqrt(t33));
      }
    }
  }
  return ok;
}

//
// Arguments    : double y
//                double x
// Return Type  : double
//
namespace coder {
static double b_atan2(double y, double x)
{
  double r;
  if (std::isnan(y) || std::isnan(x)) {
    r = rtNaN;
  } else if (std::isinf(y) && std::isinf(x)) {
    int i;
    int i1;
    if (y > 0.0) {
      i = 1;
    } else {
      i = -1;
    }
    if (x > 0.0) {
      i1 = 1;
    } else {
      i1 = -1;
    }
    r = std::atan2(static_cast<double>(i), static_cast<double>(i1));
  } else if (x == 0.0) {
    if (y > 0.0) {
      r = RT_PI / 2.0;
    } else if (y < 0.0) {
      r = -(RT_PI / 2.0);
    } else {
      r = 0.0;
    }
  } else {
    r = std::atan2(y, x);
  }
  return r;
}

//
// Arguments    : const double a[2]
//                const double b[2]
// Return Type  : double
//
static double b_dot(const double a[2], const double b[2])
{
  return a[0] * b[0] + a[1] * b[1];
}

//
// Arguments    : double b_I[324]
// Return Type  : void
//
static void b_eye(double b_I[324])
{
  std::memset(&b_I[0], 0, 324U * sizeof(double));
  for (int k{0}; k < 18; k++) {
    b_I[k + 18 * k] = 1.0;
  }
}

//
// Arguments    : double x
//                double y
// Return Type  : double
//
static double b_hypot(double x, double y)
{
  double b;
  double r;
  r = std::abs(x);
  b = std::abs(y);
  if (r < b) {
    r /= b;
    r = b * std::sqrt(r * r + 1.0);
  } else if (r > b) {
    b /= r;
    r *= std::sqrt(b * b + 1.0);
  } else if (std::isnan(b)) {
    r = rtNaN;
  } else {
    r *= 1.4142135623730951;
  }
  return r;
}

//
// Arguments    : double x
//                double y
// Return Type  : double
//
static double b_mod(double x, double y)
{
  double r;
  if (y == 0.0) {
    r = x;
    if (x == 0.0) {
      r = 0.0;
    }
  } else if (std::isnan(x) || std::isnan(y) || std::isinf(x)) {
    r = rtNaN;
  } else if (std::isinf(y)) {
    if (y > 0.0) {
      if (x > 0.0) {
        r = x;
      } else if (x < 0.0) {
        r = y;
      } else {
        r = 0.0;
      }
    } else if (x > 0.0) {
      r = rtNaN;
    } else if (x < 0.0) {
      r = x;
    } else {
      r = -0.0;
    }
  } else {
    if (y > std::floor(y)) {
      r = std::abs(x / y);
      if (std::abs(r - std::floor(r + 0.5)) > 2.2204460492503131E-16 * r) {
        r = std::fmod(x, y);
      } else {
        r = 0.0;
      }
    } else {
      r = std::fmod(x, y);
    }
    if (r == 0.0) {
      r = y * 0.0;
    } else if ((r < 0.0) && (y > 0.0)) {
      r += y;
    }
  }
  return r;
}

//
// Arguments    : const double x[3]
// Return Type  : double
//
static double b_norm(const double x[3])
{
  double absxk;
  double scale;
  double t;
  double y;
  bool b;
  scale = 3.3121686421112381E-170;
  absxk = std::abs(x[0]);
  if (absxk > 3.3121686421112381E-170) {
    y = 1.0;
    scale = absxk;
  } else {
    t = absxk / 3.3121686421112381E-170;
    y = t * t;
  }
  absxk = std::abs(x[1]);
  if (absxk > scale) {
    t = scale / absxk;
    y = y * t * t + 1.0;
    scale = absxk;
  } else {
    t = absxk / scale;
    y += t * t;
  }
  absxk = std::abs(x[2]);
  if (absxk > scale) {
    t = scale / absxk;
    y = y * t * t + 1.0;
    scale = absxk;
  } else {
    t = absxk / scale;
    y += t * t;
  }
  y = scale * std::sqrt(y);
  b = std::isnan(y);
  if (b) {
    int k;
    k = 0;
    int exitg1;
    do {
      exitg1 = 0;
      if (k < 3) {
        if (std::isnan(x[k])) {
          exitg1 = 1;
        } else {
          k++;
        }
      } else {
        y = rtInf;
        exitg1 = 1;
      }
    } while (exitg1 == 0);
  }
  return y;
}

//
// Arguments    : const double x[2]
// Return Type  : double
//
static double c_norm(const double x[2])
{
  double absxk;
  double scale;
  double t;
  double y;
  bool b;
  scale = 3.3121686421112381E-170;
  absxk = std::abs(x[0]);
  if (absxk > 3.3121686421112381E-170) {
    y = 1.0;
    scale = absxk;
  } else {
    t = absxk / 3.3121686421112381E-170;
    y = t * t;
  }
  absxk = std::abs(x[1]);
  if (absxk > scale) {
    t = scale / absxk;
    y = y * t * t + 1.0;
    scale = absxk;
  } else {
    t = absxk / scale;
    y += t * t;
  }
  y = scale * std::sqrt(y);
  b = std::isnan(y);
  if (b) {
    int k;
    k = 0;
    int exitg1;
    do {
      exitg1 = 0;
      if (k < 2) {
        if (std::isnan(x[k])) {
          exitg1 = 1;
        } else {
          k++;
        }
      } else {
        y = rtInf;
        exitg1 = 1;
      }
    } while (exitg1 == 0);
  }
  return y;
}

//
// Arguments    : const double a[3]
//                const double b[3]
// Return Type  : double
//
static double dot(const double a[3], const double b[3])
{
  return (a[0] * b[0] + a[1] * b[1]) + a[2] * b[2];
}

//
// Arguments    : double b_I[9]
// Return Type  : void
//
static void eye(double b_I[9])
{
  std::memset(&b_I[0], 0, 9U * sizeof(double));
  b_I[0] = 1.0;
  b_I[4] = 1.0;
  b_I[8] = 1.0;
}

//
// Arguments    : double x
// Return Type  : double
//
namespace internal {
namespace scalar {
static double c_mod(double x)
{
  double r;
  if (std::isnan(x) || std::isinf(x)) {
    r = rtNaN;
  } else {
    r = std::abs(x / 6.2831853071795862);
    if (std::abs(r - std::floor(r + 0.5)) > 2.2204460492503131E-16 * r) {
      r = std::fmod(x, 6.2831853071795862);
    } else {
      r = 0.0;
    }
    if (r == 0.0) {
      r = 0.0;
    } else if (r < 0.0) {
      r += 6.2831853071795862;
    }
  }
  return r;
}

//
// Arguments    : const double varargin_1[4]
//                const double varargin_2[4]
//                double varargin_3
// Return Type  : double
//
} // namespace scalar
} // namespace internal
static double interp1(const double varargin_1[4], const double varargin_2[4],
                      double varargin_3)
{
  double x[4];
  double y[4];
  double Vq;
  y[0] = varargin_2[0];
  x[0] = varargin_1[0];
  y[1] = varargin_2[1];
  x[1] = varargin_1[1];
  y[2] = varargin_2[2];
  x[2] = varargin_1[2];
  y[3] = varargin_2[3];
  x[3] = varargin_1[3];
  if (varargin_1[1] < varargin_1[0]) {
    x[0] = varargin_1[3];
    x[3] = varargin_1[0];
    y[0] = varargin_2[3];
    y[3] = varargin_2[0];
    x[1] = varargin_1[2];
    x[2] = varargin_1[1];
    y[1] = varargin_2[2];
    y[2] = varargin_2[1];
  }
  if (std::isnan(varargin_3)) {
    Vq = rtNaN;
  } else if (varargin_3 > x[3]) {
    Vq = y[3] + (varargin_3 - x[3]) / (x[3] - x[2]) * (y[3] - y[2]);
  } else if (varargin_3 < x[0]) {
    Vq = y[0] + (varargin_3 - x[0]) / (x[1] - x[0]) * (y[1] - y[0]);
  } else {
    double r;
    int high_i;
    int low_i;
    int low_ip1;
    low_i = 1;
    low_ip1 = 2;
    high_i = 4;
    while (high_i > low_ip1) {
      int mid_i;
      mid_i = (low_i + high_i) >> 1;
      if (varargin_3 >= x[mid_i - 1]) {
        low_i = mid_i;
        low_ip1 = mid_i + 1;
      } else {
        high_i = mid_i;
      }
    }
    Vq = x[low_i - 1];
    r = (varargin_3 - Vq) / (x[low_i] - Vq);
    if (r == 0.0) {
      Vq = y[low_i - 1];
    } else if (r == 1.0) {
      Vq = y[low_i];
    } else {
      Vq = y[low_i - 1];
      if (!(Vq == y[low_i])) {
        Vq = (1.0 - r) * Vq + r * y[low_i];
      }
    }
  }
  return Vq;
}

//
// Arguments    : double &lambda
// Return Type  : void
//
static void wrapToPi(double &lambda)
{
  double q;
  double tmp_data;
  double varargin_1;
  double varargout_1;
  int b_trueCount;
  int trueCount;
  bool b;
  b = ((lambda < -3.1415926535897931) || (lambda > 3.1415926535897931));
  trueCount = 0;
  if (b) {
    varargin_1 = lambda + 3.1415926535897931;
    if (std::isnan(varargin_1) || std::isinf(varargin_1)) {
      tmp_data = rtNaN;
    } else {
      q = std::abs(varargin_1 / 6.2831853071795862);
      if (std::abs(q - std::floor(q + 0.5)) > 2.2204460492503131E-16 * q) {
        tmp_data = std::fmod(varargin_1, 6.2831853071795862);
      } else {
        tmp_data = 0.0;
      }
      if (tmp_data == 0.0) {
        tmp_data = 0.0;
      } else if (tmp_data < 0.0) {
        tmp_data += 6.2831853071795862;
      }
    }
    trueCount = 1;
  }
  b_trueCount = 0;
  if (trueCount - 1 >= 0) {
    varargin_1 = lambda + 3.1415926535897931;
    if (std::isnan(varargin_1) || std::isinf(varargin_1)) {
      varargout_1 = rtNaN;
    } else {
      q = std::abs(varargin_1 / 6.2831853071795862);
      if (std::abs(q - std::floor(q + 0.5)) > 2.2204460492503131E-16 * q) {
        varargout_1 = std::fmod(varargin_1, 6.2831853071795862);
      } else {
        varargout_1 = 0.0;
      }
      if (varargout_1 == 0.0) {
        varargout_1 = 0.0;
      } else if (varargout_1 < 0.0) {
        varargout_1 += 6.2831853071795862;
      }
    }
  }
  for (int i{0}; i < trueCount; i++) {
    if ((varargout_1 == 0.0) && (lambda + 3.1415926535897931 > 0.0)) {
      b_trueCount++;
    }
  }
  if (b_trueCount - 1 >= 0) {
    tmp_data = 6.2831853071795862;
  }
  varargin_1 = lambda;
  if (b) {
    varargin_1 = tmp_data - 3.1415926535897931;
  }
  lambda = varargin_1;
}

//
// CONTROLLER_CODEGEN_STEP Explicit-state one-step controller (fixed ABI).
//  DEPLOY_CANDIDATE / NOT_IN_PRODUCTION — isolated prototype; not production
//  path. Translates accepted controller_law arithmetic/order exactly.
//  TEMPORARY_BLOCKER: wrapToPi (yaw wrap) and fixed-table interp1 linear/extrap
//  remain for bit parity; ownership replacement is a later gate.
//
//  Constraints: no global/persistent/nargin/nargout/isempty defaults/dynamic
//  fields/allocation/logging/error/assert. Fixed
//  Params/State/Input/Output/Debug.
//
//  TASK_ID: CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE_001
//
// Arguments    : const struct1_T &params
//                struct10_T &state
//                const struct_T &in
// Return Type  : b_struct_T
//
} // namespace coder
static b_struct_T controller_codegen_step(const struct1_T &params,
                                          struct10_T &state, const struct_T &in)
{
  b_struct_T out;
  double a;
  double a_rate;
  double b_a;
  double de_ff_lim;
  double de_rate;
  double de_trim_tmp;
  double e_psi;
  double e_r;
  double e_rate;
  double e_theta;
  double int_angle;
  double int_rate;
  double int_rate_max;
  double rate_filt;
  //  ----- Yaw + roll-rate damp (sum BEFORE mag/rate limit; Kphi=0) -----
  //  TEMPORARY_BLOCKER: wrapToPi retained for golden bit parity.
  e_psi = in.yaw_ref - in.psi;
  coder::wrapToPi(e_psi);
  e_r = in.r - in.r_ff;
  a = e_psi / 0.05235987755982989;
  b_a = e_r / 0.13962634015954636;
  //  ----- Physical pitch kinematics -----
  a_rate = std::exp(-params.dt_controller / params.tau_rate);
  rate_filt =
      a_rate * state.rate_filt +
      (1.0 - a_rate) * (-in.q * std::cos(in.phi) + in.r * std::sin(in.phi));
  e_theta = in.pitch_ref - (-in.theta);
  //  Outer loop: angle -> rate command
  a_rate = 0.13962634015954636 / std::fmax(params.Ki_angle, 1.0E-6);
  int_angle = std::fmax(
      std::fmin(state.int_angle + e_theta * params.dt_controller, a_rate),
      -a_rate);
  //  Inner loop: rate -> elevator (+ damping on measured rate)
  e_rate =
      std::fmax(std::fmin((0.8 * in.pitch_ref_dot + params.Kp_angle * e_theta) +
                              params.Ki_angle * int_angle,
                          0.24434609527920614),
                -0.24434609527920614) -
      rate_filt;
  de_rate = 0.0;
  if (params.Kd_rate > 0.0) {
    de_rate =
        std::fmax(std::fmin((e_rate - state.prev_e_rate) / params.dt_controller,
                            0.43633231299858238),
                  -0.43633231299858238);
  }
  //  TEMPORARY_BLOCKER: fixed-table interp1 linear/extrap retained for parity.
  de_trim_tmp = std::abs(in.u);
  int_rate_max = 0.087266462599716474 / std::fmax(params.Ki_rate, 1.0E-6);
  int_rate = std::fmax(
      std::fmin(state.int_rate + e_rate * params.dt_controller, int_rate_max),
      -int_rate_max);
  //  Climb equilibrium FF (scheduled on physical pitch_ref; not I memory)
  //  Tur 3: graduated Muw feedforward (additive; λ=0 => identically zero)
  a_rate = params.Muuds *
           std::fmax(in.u * in.u, params.muw_ff_u_min * params.muw_ff_u_min);
  if ((std::abs(a_rate) < 1.0E-9) || (params.lambda_muw_ff == 0.0)) {
    a_rate = 0.0;
  } else {
    a_rate = -params.lambda_muw_ff * (params.Muw * in.u * in.w) / a_rate;
  }
  de_ff_lim = 0.017453292519943295 * params.muw_ff_clamp_deg;
  a_rate = ((coder::interp1(params.trim_speed_table, params.trim_elevator_table,
                            de_trim_tmp) +
             std::fmax(0.0, std::fmin(1.0, (de_trim_tmp - params.muw_ff_u_lo) /
                                               std::fmax(params.muw_ff_u_hi -
                                                             params.muw_ff_u_lo,
                                                         1.0E-6))) *
                 std::fmax(std::fmin(a_rate, de_ff_lim), -de_ff_lim)) +
            std::fmax(std::fmin(params.k_gamma_climb * in.pitch_ref,
                                params.de_climb_lim),
                      -params.de_climb_lim)) +
           params.elevator_sign *
               (((params.Kp_rate * e_rate + params.Ki_rate * int_rate) +
                 params.Kd_rate * de_rate) -
                params.Kd_damp * rate_filt);
  de_rate =
      std::fmax(std::fmin(a_rate, params.delta_e_max), -params.delta_e_max);
  //  Back-calculation anti-windup on rate integrator
  a_rate = de_rate - a_rate;
  state.int_rate = std::fmax(
      std::fmin(int_rate + params.Kaw_pitch * a_rate * params.dt_controller,
                int_rate_max),
      -int_rate_max);
  //  Soft freeze outer I if persistently saturated against error
  if (std::abs(a_rate) > 0.0001) {
    a_rate *= params.elevator_sign;
    if (std::isnan(a_rate)) {
      a_rate = rtNaN;
    } else if (a_rate < 0.0) {
      a_rate = -1.0;
    } else {
      a_rate = (a_rate > 0.0);
    }
    if (std::isnan(e_theta)) {
      de_ff_lim = rtNaN;
    } else if (e_theta < 0.0) {
      de_ff_lim = -1.0;
    } else {
      de_ff_lim = (e_theta > 0.0);
    }
    if (de_ff_lim == a_rate) {
      int_angle -= 0.5 * e_theta * params.dt_controller;
    }
  }
  a_rate = 0.69813170079773179 * params.dt_controller;
  de_ff_lim =
      state.prev_delta_r +
      std::fmax(
          std::fmin(std::fmax(std::fmin((params.Kp_psi * e_psi -
                                         params.Kd_psi * e_r) +
                                            1.0 / ((a * a + 1.0) + b_a * b_a) *
                                                (-params.Kp_roll * in.p),
                                        params.delta_r_max),
                              -params.delta_r_max) -
                        state.prev_delta_r,
                    a_rate),
          -a_rate);
  a_rate = state.prev_delta_e +
           std::fmax(std::fmin(de_rate - state.prev_delta_e, a_rate), -a_rate);
  out.thrust =
      std::fmax(std::fmin(params.thrust_trim + params.Kp_x * (in.u_ref - in.u),
                          params.thrust_max),
                params.thrust_min);
  //  ----- write-back State (fixed fields) -----
  state.prev_delta_r = de_ff_lim;
  state.prev_delta_e = a_rate;
  state.int_angle = int_angle;
  state.rate_filt = rate_filt;
  state.prev_e_rate = e_rate;
  state.initialized = 1.0;
  //  ----- Output (fixed fields) -----
  out.delta_r = de_ff_lim;
  out.delta_e = a_rate;
  //  ----- Debug (fixed fields; always emitted) -----
  return out;
}

//
// GUIDANCE_CODEGEN_STEP Explicit-state one-step guidance (fixed ABI).
//  DEPLOY_CANDIDATE / NOT_IN_PRODUCTION — isolated prototype; not production
//  path. Translates accepted guidance_law arithmetic/order exactly. Fixed
//  32-node buffers; bounded loops over n_path; local wrap_pi_local.
//
//  Constraints: no global/persistent/nargin defaults/find/dynamic path slice/
//  wrapToPi/file I/O. Preserves cold-start have-flags and accepted gains.
//
//  TASK_ID: CG2B_GUIDANCE_EXPLICIT_STATE_PROTOTYPE_001
//
// Arguments    : const double pos[3]
//                const double path_pad[96]
//                double n_path
//                double progress_index
//                double u_body
//                double v_body
//                double U_h
//                double zdot_inertial
//                double theta_phys
//                const struct2_T &cfg
//                struct11_T &state
//                double &pitch_ref
//                double &u_ref
//                double &next_progress_index
//                double &r_ff
//                double &pitch_ref_dot
// Return Type  : double
//
static double guidance_codegen_step(
    const double pos[3], const double path_pad[96], double n_path,
    double progress_index, double u_body, double v_body, double U_h,
    double zdot_inertial, double theta_phys, const struct2_T &cfg,
    struct11_T &state, double &pitch_ref, double &u_ref,
    double &next_progress_index, double &r_ff, double &pitch_ref_dot)
{
  double s_nodes[32];
  double alpha_hat;
  double chi_f;
  double eg_f;
  double gamma_actual;
  double kappa_f;
  double kappa_raw;
  double pitch_f;
  double pitch_out;
  double s_look;
  double s_prog;
  double yaw_cont;
  double yaw_ref;
  double z_e_f;
  double z_e_i;
  double zd_e_f;
  bool have_chi_f;
  bool have_pitch_f;
  bool have_yaw_cont;
  s_prog = state.s_prog;
  yaw_cont = state.yaw_cont;
  pitch_f = state.pitch_f;
  z_e_f = state.z_e_f;
  z_e_i = state.z_e_i;
  zd_e_f = state.zd_e_f;
  eg_f = state.eg_f;
  alpha_hat = state.alpha_hat;
  kappa_f = state.kappa_f;
  chi_f = state.chi_f;
  yaw_ref = state.yaw_out;
  pitch_out = state.pitch_out;
  have_yaw_cont = state.have_yaw_cont;
  have_pitch_f = state.have_pitch_f;
  have_chi_f = state.have_chi_f;
  U_h = std::fmax(U_h, 0.0);
  if (n_path < 2.0) {
    yaw_ref = 0.0;
    pitch_ref = 0.0;
    u_ref = cfg.desired_speed;
    next_progress_index = 1.0;
    r_ff = 0.0;
    pitch_ref_dot = 0.0;
  } else {
    double a__3[3];
    double p_path[3];
    double t1[3];
    double t2[3];
    double t_hat[3];
    double t_look[3];
    double b_b[2];
    double L;
    double a_idx_0;
    double a_idx_1;
    double ds;
    double s_prev;
    int b_i;
    int cnt;
    bool b;
    bool have_s_prev;
    bool is_closed;
    bool near_end;
    //  Arc-length table (fixed 32-buffer; active length n)
    //  ===== helpers (fixed buffers / bounded loops; no find) =====
    std::memset(&s_nodes[0], 0, 32U * sizeof(double));
    cnt = static_cast<int>(n_path - 1.0);
    for (int i{0}; i < cnt; i++) {
      p_path[0] = path_pad[i + 1] - path_pad[i];
      p_path[1] = path_pad[i + 33] - path_pad[i + 32];
      p_path[2] = path_pad[i + 65] - path_pad[i + 64];
      s_nodes[i + 1] = s_nodes[i] + coder::b_norm(p_path);
    }
    a_idx_1 = s_nodes[static_cast<int>(n_path) - 1];
    a_idx_0 = a_idx_1;
    if (a_idx_1 < 1.0E-9) {
      a_idx_0 = 1.0E-9;
    }
    p_path[0] = path_pad[0] - path_pad[static_cast<int>(n_path) - 1];
    p_path[1] = path_pad[32] - path_pad[static_cast<int>(n_path) + 31];
    p_path[2] = path_pad[64] - path_pad[static_cast<int>(n_path) + 63];
    is_closed = (coder::b_norm(p_path) < 0.25);
    L = std::fmax(cfg.lookahead_distance, 1.0);
    //  too-small L amplifies projection chatter
    //  --- Nearest projection with monotonic progress ---
    have_s_prev = false;
    s_prev = 0.0;
    if (!state.initialized) {
      if (is_closed && (a_idx_0 > a_idx_1)) {
        ds = project_interval_fixed(pos, path_pad, s_nodes, n_path, 0.0,
                                    a_idx_1, kappa_raw);
        s_prog = project_interval_fixed(pos, path_pad, s_nodes, n_path, 0.0,
                                        coder::b_mod(a_idx_0, a_idx_1), s_look);
        if (kappa_raw <= s_look) {
          s_prog = ds;
        }
      } else {
        s_prog = project_interval_fixed(pos, path_pad, s_nodes, n_path, 0.0,
                                        std::fmin(a_idx_1, a_idx_0), kappa_raw);
      }
      yaw_cont = 0.0;
      pitch_f = 0.0;
      //  cold-start from path slope (critical for XZ)
      z_e_f = 0.0;
      z_e_i = 0.0;
      zd_e_f = 0.0;
      eg_f = 0.0;
      alpha_hat = 0.0;
      kappa_f = 0.0;
      chi_f = 0.0;
      have_yaw_cont = false;
      have_pitch_f = false;
      have_chi_f = false;
    } else {
      bool guard1;
      s_prev = state.s_prog;
      have_s_prev = true;
      //  Only search a forward window in arc-length (prevents back-jumps)
      //  tiny backward tolerance
      kappa_raw = std::fmax(3.0, 2.5 * L);
      //  forward window
      guard1 = false;
      if (is_closed) {
        s_look = coder::b_mod(state.s_prog - 0.15, a_idx_0);
        ds = s_look + kappa_raw;
        if (ds > a_idx_1) {
          kappa_raw = project_interval_fixed(pos, path_pad, s_nodes, n_path,
                                             s_look, a_idx_1, gamma_actual);
          ds = project_interval_fixed(pos, path_pad, s_nodes, n_path, 0.0,
                                      coder::b_mod(ds, a_idx_1), s_look);
          if (gamma_actual <= s_look) {
            ds = kappa_raw;
          }
        } else {
          guard1 = true;
        }
      } else {
        s_look = std::fmax(0.0, state.s_prog - 0.15);
        ds = std::fmin(a_idx_0, state.s_prog + kappa_raw);
        guard1 = true;
      }
      if (guard1) {
        ds = project_interval_fixed(pos, path_pad, s_nodes, n_path,
                                    std::fmax(0.0, s_look),
                                    std::fmin(a_idx_1, ds), kappa_raw);
      }
      //  Monotonic blend: never fall back more than 5 cm on open paths
      if (is_closed) {
        kappa_raw = 0.5 * a_idx_0;
        kappa_raw =
            coder::b_mod((ds - state.s_prog) + kappa_raw, a_idx_0) - kappa_raw;
        if (!(kappa_raw < -0.25)) {
          s_prog =
              coder::b_mod(state.s_prog + std::fmax(kappa_raw, -0.05), a_idx_0);
        } else {
          //  ignore large backward snap
        }
      } else {
        s_prog = std::fmin(std::fmax(state.s_prog, ds - 0.05), a_idx_0);
      }
    }
    b = !is_closed;
    if (b && (s_prog >= a_idx_0 - 0.3)) {
      near_end = true;
    } else {
      near_end = false;
    }
    //  Path pose at progress and at lookahead
    sample_path_fixed(path_pad, s_nodes, n_path, s_prog, is_closed, p_path,
                      t_hat);
    s_look = s_prog + L;
    if (is_closed) {
      s_look = coder::b_mod(s_look, a_idx_0);
    } else {
      s_look = std::fmin(s_look, a_idx_0);
    }
    sample_path_fixed(path_pad, s_nodes, n_path, s_look, is_closed, a__3,
                      t_look);
    //  Mild progress hold only for large depth lag (avoid depth-loop fight)
    if (have_s_prev && b && (p_path[2] - pos[2] > 2.5)) {
      //  >0 => vehicle below path
      s_prog = std::fmin(
          s_prog, s_prev + std::fmax(0.05, 0.55 * std::fmax(u_body, 0.3) *
                                               cfg.dt_guidance));
      sample_path_fixed(path_pad, s_nodes, n_path, s_prog, false, p_path,
                        t_hat);
      sample_path_fixed(path_pad, s_nodes, n_path,
                        std::fmin(a_idx_0, s_prog + L), false, a__3, t_look);
    }
    //  Curvature (smoothed)
    ds = std::fmax(0.4, 0.05 * a_idx_1);
    sample_path_fixed(path_pad, s_nodes, n_path, s_prog - ds, is_closed, a__3,
                      t1);
    sample_path_fixed(path_pad, s_nodes, n_path, s_prog + ds, is_closed, a__3,
                      t2);
    kappa_raw = coder::c_norm(&t1[0]);
    if (kappa_raw < 1.0E-9) {
      kappa_raw = 0.0;
    } else {
      s_look = coder::c_norm(&t2[0]);
      if (s_look < 1.0E-9) {
        kappa_raw = 0.0;
      } else {
        a_idx_0 = t1[0] / kappa_raw;
        b_b[0] = t2[0] / s_look;
        a_idx_1 = t1[1] / kappa_raw;
        b_b[1] = t2[1] / s_look;
        kappa_raw = coder::b_atan2(a_idx_0 * b_b[1] - b_b[0] * a_idx_1,
                                   a_idx_0 * b_b[0] + a_idx_1 * b_b[1]) /
                    (2.0 * ds);
      }
    }
    kappa_f = 0.96 * kappa_f + 0.04 * kappa_raw;
    //  heavy smooth — kappa chatter -> rudder chatter
    kappa_raw = 1.0 / std::fmax(std::abs(kappa_f), 0.0001);
    //  Cross-track (vehicle - path), filter vertical error
    p_path[0] = pos[0] - p_path[0];
    p_path[1] = pos[1] - p_path[1];
    p_path[2] = pos[2] - p_path[2];
    gamma_actual = coder::c_norm(&t_hat[0]);
    if (gamma_actual < 1.0E-9) {
      a_idx_0 = 1.0;
      a_idx_1 = 0.0;
    } else {
      a_idx_0 = t_hat[0] / gamma_actual;
      a_idx_1 = t_hat[1] / gamma_actual;
    }
    z_e_f = 0.93 * z_e_f + 0.07 * p_path[2];
    //  heavier filter — depth loop was oscillating
    //  Speed schedule
    u_ref = std::fmax(
        0.9, std::fmin(cfg.desired_speed,
                       cfg.desired_speed * (kappa_raw / (kappa_raw + 2.5))));
    if (std::abs(z_e_f) > 3.0) {
      u_ref = std::fmin(u_ref, 1.15);
    }
    if (near_end) {
      u_ref = 0.7 * cfg.desired_speed;
    }
    //  --- Yaw: filter COURSE first (before unwrap), then soft CTE ---
    kappa_raw = coder::b_atan2(t_look[1], t_look[0]);
    if (!have_chi_f) {
      chi_f = kappa_raw;
    } else {
      kappa_raw -= chi_f;
      //  Owned scalar wrap to [-pi, pi]; accepted wrapToPi branch semantics.
      if ((!(kappa_raw >= -3.1415926535897931)) ||
          (!(kappa_raw <= 3.1415926535897931))) {
        s_look = coder::internal::scalar::c_mod(kappa_raw + 3.1415926535897931);
        if ((s_look == 0.0) && (kappa_raw + 3.1415926535897931 > 0.0)) {
          s_look = 6.2831853071795862;
        }
        kappa_raw = s_look - 3.1415926535897931;
      }
      chi_f += 0.28 * kappa_raw;
      //  faster course tracking
    }
    //  stronger lateral LOS for circle radius
    //  Sideslip compensation: psi_ref = path + LOS - k_beta*beta (crab)
    if (near_end) {
      ds = coder::b_atan2(t_hat[1], t_hat[0]);
    } else {
      b_b[0] = -a_idx_1;
      b_b[1] = a_idx_0;
      ds = (chi_f +
            0.75 * coder::b_atan2(-coder::b_dot(&p_path[0], b_b), L + 0.6)) -
           1.35 * coder::b_atan2(v_body, std::fmax(u_body, 0.35));
      //  Owned scalar wrap to [-pi, pi]; accepted wrapToPi branch semantics.
      if ((!(ds >= -3.1415926535897931)) || (!(ds <= 3.1415926535897931))) {
        s_look = coder::internal::scalar::c_mod(ds + 3.1415926535897931);
        if ((s_look == 0.0) && (ds + 3.1415926535897931 > 0.0)) {
          s_look = 6.2831853071795862;
        }
        ds = s_look - 3.1415926535897931;
      }
    }
    //  Continuous unwrap (kills ±pi step impulses)
    if (!have_yaw_cont) {
      yaw_cont = ds;
    } else {
      s_look = ds - yaw_cont;
      //  Owned scalar wrap to [-pi, pi]; accepted wrapToPi branch semantics.
      if ((!(s_look >= -3.1415926535897931)) ||
          (!(s_look <= 3.1415926535897931))) {
        kappa_raw = coder::internal::scalar::c_mod(s_look + 3.1415926535897931);
        if ((kappa_raw == 0.0) && (s_look + 3.1415926535897931 > 0.0)) {
          kappa_raw = 6.2831853071795862;
        }
        s_look = kappa_raw - 3.1415926535897931;
      }
      yaw_cont += s_look;
    }
    //  --- Pitch ref: lookahead path slope + stronger depth catch-up ---
    //  also blend current-segment slope so end-of-path doesn't zero pitch early
    a_idx_1 = coder::b_atan2(t_hat[2], std::fmax(gamma_actual, 1.0E-6));
    if (!near_end) {
      a_idx_1 =
          0.65 * coder::b_atan2(t_look[2],
                                std::fmax(coder::c_norm(&t_look[0]), 1.0E-6)) +
          0.35 * a_idx_1;
    }
    //  Soft depth P+I (keep P mild; I kills steady B>W / climb lag bias)
    //  Sign: cte(3)=z_veh-z_path; pitch_corr = -Kz*cte = +Kz*(z_path-z)
    //  [preserved]
    z_e_i = std::fmax(std::fmin(z_e_i + z_e_f * cfg.dt_guidance, 25.0), -25.0);
    //  Tur5A: inertial zdot error — same sign family as depth-P
    kappa_raw = std::fmax(coder::b_hypot(U_h, zdot_inertial), 0.3);
    ds = t_hat[2] * kappa_raw;
    //  unit tangent * inertial speed
    //  vehicle-minus-path (like cte)
    zd_e_f = 0.85 * zd_e_f + 0.15 * (zdot_inertial - ds);
    a_idx_0 = std::fmax(
        std::fmin((-0.05 * z_e_f - 0.006 * z_e_i) - cfg.K_zdot * zd_e_f,
                  0.15707963267948966),
        -0.15707963267948966);
    //  Tur5B: path-angle (flight-path) gamma feedback
    gamma_actual = coder::b_atan2(zdot_inertial, std::fmax(U_h, 0.05));
    kappa_raw = coder::b_atan2(
        ds, std::fmax(kappa_raw * coder::b_hypot(t_hat[0], t_hat[1]), 0.05));
    s_look = kappa_raw - gamma_actual;
    //  Owned scalar wrap to [-pi, pi]; accepted wrapToPi branch semantics.
    if ((!(s_look >= -3.1415926535897931)) ||
        (!(s_look <= 3.1415926535897931))) {
      ds = coder::internal::scalar::c_mod(s_look + 3.1415926535897931);
      if ((ds == 0.0) && (s_look + 3.1415926535897931 > 0.0)) {
        ds = 6.2831853071795862;
      }
      s_look = ds - 3.1415926535897931;
    }
    eg_f = 0.85 * eg_f + 0.15 * s_look;
    if (cfg.enable_alpha_hat && (u_body >= 0.5)) {
      //  Slow AoA estimate; limited; off at low surge
      alpha_hat = std::fmax(
          std::fmin(0.98 * alpha_hat + 0.02 * (theta_phys - gamma_actual),
                    0.13962634015954636),
          -0.13962634015954636);
      kappa_raw = ((kappa_raw + cfg.K_gamma * eg_f) + a_idx_0) + alpha_hat;
    } else {
      alpha_hat *= 0.98;
      //  bleed off when disabled / low-u
      kappa_raw = (a_idx_1 + cfg.K_gamma * eg_f) + a_idx_0;
      //  theta_path + K_gamma*e_gamma + depth[+zdot]
    }
    kappa_raw =
        std::fmax(std::fmin(kappa_raw, cfg.pitch_ref_max), -cfg.pitch_ref_max);
    if (!have_pitch_f) {
      pitch_f = kappa_raw;
      //  cold start = path slope (avoids 0→22° dive)
      pitch_out = kappa_raw;
    } else {
      pitch_f = 0.9 * pitch_f + 0.1 * kappa_raw;
    }
    ds = 0.69813170079773179 * cfg.dt_guidance;
    //  allow tracking circle rate ~u/R
    if (!state.have_yaw_out) {
      yaw_ref = yaw_cont;
      pitch_out = pitch_f;
    }
    yaw_ref += std::fmax(std::fmin(0.35 * (yaw_cont - yaw_ref), ds), -ds);
    //  Explicit pitch ref rate limit
    s_look = cfg.pitch_ref_rate_max * cfg.dt_guidance;
    kappa_raw = std::fmax(std::fmin(pitch_f - pitch_out, s_look), -s_look);
    pitch_out = std::fmax(std::fmin(pitch_out + kappa_raw, cfg.pitch_ref_max),
                          -cfg.pitch_ref_max);
    pitch_ref = pitch_out;
    pitch_ref_dot = kappa_raw / cfg.dt_guidance;
    //  Tur4A: yaw-rate FF from inertial horizontal speed × path curvature
    r_ff = std::fmax(std::fmin(U_h * kappa_f, 0.69813170079773179),
                     -0.69813170079773179);
    //  Integer index for suite progress (display / legacy) — bounded count, no
    //  sum/find
    cnt = 0;
    b_i = static_cast<int>(n_path);
    for (int i{0}; i < b_i; i++) {
      if (s_nodes[i] <= s_prog) {
        cnt++;
      }
    }
    next_progress_index = std::fmin(n_path, static_cast<double>(cnt) + 1.0);
    if (b) {
      next_progress_index = std::fmax(next_progress_index, progress_index);
    }
    //  ----- write-back State (legacy persistent fields) -----
    state.initialized = true;
    state.s_prog = s_prog;
    state.yaw_cont = yaw_cont;
    state.pitch_f = pitch_f;
    state.z_e_f = z_e_f;
    state.z_e_i = z_e_i;
    state.zd_e_f = zd_e_f;
    state.eg_f = eg_f;
    state.alpha_hat = alpha_hat;
    state.kappa_f = kappa_f;
    state.chi_f = chi_f;
    state.yaw_out = yaw_ref;
    state.pitch_out = pitch_out;
    state.have_yaw_cont = true;
    state.have_pitch_f = true;
    state.have_chi_f = true;
    state.have_yaw_out = true;
  }
  return yaw_ref;
}

//
// Arguments    : const double A[9]
//                double Ainv[9]
// Return Type  : bool
//
static bool inv3_fixed(const double A[9], double Ainv[9])
{
  double c11;
  double c12;
  double c13;
  double detA;
  bool ok;
  std::memset(&Ainv[0], 0, 9U * sizeof(double));
  c11 = A[4] * A[8] - A[5] * A[7];
  c12 = A[2] * A[7] - A[1] * A[8];
  c13 = A[1] * A[5] - A[2] * A[4];
  detA = (A[0] * c11 + A[3] * c12) + A[6] * c13;
  ok = false;
  if ((!std::isinf(detA)) && (!std::isnan(detA))) {
    double adet;
    adet = detA;
    if (detA < 0.0) {
      adet = -detA;
    }
    if (adet > 1.0E-18) {
      Ainv[0] = c11 / detA;
      Ainv[3] = (A[5] * A[6] - A[3] * A[8]) / detA;
      Ainv[6] = (A[3] * A[7] - A[4] * A[6]) / detA;
      Ainv[1] = c12 / detA;
      Ainv[4] = (A[0] * A[8] - A[2] * A[6]) / detA;
      Ainv[7] = (A[1] * A[6] - A[0] * A[7]) / detA;
      Ainv[2] = c13 / detA;
      Ainv[5] = (A[2] * A[3] - A[0] * A[5]) / detA;
      Ainv[8] = (A[0] * A[4] - A[1] * A[3]) / detA;
      if ((!std::isinf(Ainv[0])) && (!std::isnan(Ainv[0])) &&
          ((!std::isinf(Ainv[3])) && (!std::isnan(Ainv[3]))) &&
          ((!std::isinf(Ainv[6])) && (!std::isnan(Ainv[6]))) &&
          ((!std::isinf(Ainv[1])) && (!std::isnan(Ainv[1]))) &&
          ((!std::isinf(Ainv[4])) && (!std::isnan(Ainv[4]))) &&
          ((!std::isinf(Ainv[7])) && (!std::isnan(Ainv[7]))) &&
          ((!std::isinf(Ainv[2])) && (!std::isnan(Ainv[2]))) &&
          ((!std::isinf(Ainv[5])) && (!std::isnan(Ainv[5]))) &&
          ((!std::isinf(Ainv[8])) && (!std::isnan(Ainv[8])))) {
        ok = true;
      }
    }
  }
  return ok;
}

//
// NAV_CODEGEN_STEP Explicit-state Gate 5C navigation step (fixed ABI).
//  DEPLOY_CANDIDATE / NOT_IN_PRODUCTION / NOT_CERTIFIED
//  Isolated runtime: initialize / paired-IMU propagate / one aiding update /
//  output. Joseph form, ordered fail-silent admission, measured-only ABI.
//
//  op uint8: 0 output, 1 initialize, 2 propagate, 3 aiding update. Other:
//  BAD_OP.
//
//  TASK_ID: NAV_RUNTIME_REPAIR_001
//
// Arguments    : const struct6_T &params
//                struct12_T &state
//                const struct16_T &in
//                c_struct_T &out
// Return Type  : void
//
static void nav_codegen_step(const struct6_T &params, struct12_T &state,
                             const struct16_T &in, c_struct_T &out)
{
  static const double s_q[4]{1.0, 0.0, 0.0, 0.0};
  double s_P[324];
  unsigned int hb;
  bool fused;
  bool valid;
  hb = 0U;
  valid = false;
  if (!nav_state_is_finite(state.p, state.v, state.q, state.bg, state.ba,
                           state.c, state.P, state.last_ts,
                           state.last_accept_t)) {
    state.initialized = false;
    state.p[0] = 0.0;
    state.v[0] = 0.0;
    state.p[1] = 0.0;
    state.v[1] = 0.0;
    state.p[2] = 0.0;
    state.v[2] = 0.0;
    state.q[0] = 1.0;
    state.q[1] = 0.0;
    state.q[2] = 0.0;
    state.q[3] = 0.0;
    state.bg[0] = 0.0;
    state.ba[0] = 0.0;
    state.c[0] = 0.0;
    state.bg[1] = 0.0;
    state.ba[1] = 0.0;
    state.c[1] = 0.0;
    state.bg[2] = 0.0;
    state.ba[2] = 0.0;
    state.c[2] = 0.0;
    std::memset(&state.P[0], 0, 324U * sizeof(double));
    for (int i{0}; i < 7; i++) {
      state.last_seq[i] = 0U;
      state.have_seq[i] = false;
      state.last_ts[i] = 0.0;
      state.have_ts[i] = false;
      state.last_accept_t[i] = 0.0;
      state.have_accept_t[i] = false;
    }
    double s_ba[3];
    double s_bg[3];
    double s_c[3];
    double s_p[3];
    double s_v[3];
    state.est_seq = 0U;
    s_p[0] = 0.0;
    s_v[0] = 0.0;
    s_bg[0] = 0.0;
    s_ba[0] = 0.0;
    s_c[0] = 0.0;
    s_p[1] = 0.0;
    s_v[1] = 0.0;
    s_bg[1] = 0.0;
    s_ba[1] = 0.0;
    s_c[1] = 0.0;
    s_p[2] = 0.0;
    s_v[2] = 0.0;
    s_bg[2] = 0.0;
    s_ba[2] = 0.0;
    s_c[2] = 0.0;
    std::memset(&s_P[0], 0, 324U * sizeof(double));
    nav_fill_out(false, s_p, s_v, s_q, s_bg, s_ba, s_c, s_P, false, 65536U,
                 out);
  } else {
    bool guard1;
    if ((in.op != 0) && (in.op != 1) && (in.op != 2) && (in.op != 3)) {
      hb = 1U;
    } else if (!params.config_valid) {
      hb = 4U;
    } else if (in.op == 0) {
      if (!state.initialized) {
        hb = 2U;
      } else {
        valid = true;
      }
    } else if (in.op == 1) {
      hb = nav_op_initialize(params.g_ned, params.P0_p, params.P0_p_abs,
                             params.P0_v, params.P0_th, params.P0_bg,
                             params.P0_ba, params.P0_c, params.tol_pair, state,
                             in, valid);
    } else if (in.op == 2) {
      hb = nav_op_propagate(params.g_ned, params.sigma_p, params.sigma_a,
                            params.sigma_g, params.sigma_bg, params.sigma_ba,
                            params.sigma_c, params.dt_prop_max,
                            params.dt_prop_sub, params.n_sub_max,
                            params.tol_time, params.tol_pair, state, in, valid);
    } else {
      hb = nav_op_update(
          params.R_depth, params.R_heading, params.R_ins, params.R_dvl,
          params.R_usbl, params.lat_depth, params.lat_heading, params.lat_ins,
          params.lat_dvl, params.lat_usbl, params.q_min_frac, params.q_floor,
          params.nis_scale, params.tol_time, state, in, valid, fused);
    }
    if (!nav_state_is_finite(state.p, state.v, state.q, state.bg, state.ba,
                             state.c, state.P, state.last_ts,
                             state.last_accept_t)) {
      state.initialized = false;
      state.p[0] = 0.0;
      state.v[0] = 0.0;
      state.p[1] = 0.0;
      state.v[1] = 0.0;
      state.p[2] = 0.0;
      state.v[2] = 0.0;
      state.q[0] = 1.0;
      state.q[1] = 0.0;
      state.q[2] = 0.0;
      state.q[3] = 0.0;
      state.bg[0] = 0.0;
      state.ba[0] = 0.0;
      state.c[0] = 0.0;
      state.bg[1] = 0.0;
      state.ba[1] = 0.0;
      state.c[1] = 0.0;
      state.bg[2] = 0.0;
      state.ba[2] = 0.0;
      state.c[2] = 0.0;
      std::memset(&state.P[0], 0, 324U * sizeof(double));
      for (int i{0}; i < 7; i++) {
        state.last_seq[i] = 0U;
        state.have_seq[i] = false;
        state.last_ts[i] = 0.0;
        state.have_ts[i] = false;
        state.last_accept_t[i] = 0.0;
        state.have_accept_t[i] = false;
      }
      state.est_seq = 0U;
      valid = false;
      hb = 65536U;
    }
    nav_fill_out(state.initialized, state.p, state.v, state.q, state.bg,
                 state.ba, state.c, state.P, valid, hb, out);
    guard1 = false;
    if ((!std::isinf(out.p[0])) && (!std::isnan(out.p[0])) &&
        ((!std::isinf(out.p[1])) && (!std::isnan(out.p[1]))) &&
        ((!std::isinf(out.p[2])) && (!std::isnan(out.p[2]))) &&
        ((!std::isinf(out.v[0])) && (!std::isnan(out.v[0]))) &&
        ((!std::isinf(out.v[1])) && (!std::isnan(out.v[1]))) &&
        ((!std::isinf(out.v[2])) && (!std::isnan(out.v[2]))) &&
        ((!std::isinf(out.q[0])) && (!std::isnan(out.q[0]))) &&
        ((!std::isinf(out.q[1])) && (!std::isnan(out.q[1]))) &&
        ((!std::isinf(out.q[2])) && (!std::isnan(out.q[2]))) &&
        ((!std::isinf(out.q[3])) && (!std::isnan(out.q[3]))) &&
        ((!std::isinf(out.bg[0])) && (!std::isnan(out.bg[0]))) &&
        ((!std::isinf(out.bg[1])) && (!std::isnan(out.bg[1]))) &&
        ((!std::isinf(out.bg[2])) && (!std::isnan(out.bg[2]))) &&
        ((!std::isinf(out.ba[0])) && (!std::isnan(out.ba[0]))) &&
        ((!std::isinf(out.ba[1])) && (!std::isnan(out.ba[1]))) &&
        ((!std::isinf(out.ba[2])) && (!std::isnan(out.ba[2]))) &&
        ((!std::isinf(out.c[0])) && (!std::isnan(out.c[0]))) &&
        ((!std::isinf(out.c[1])) && (!std::isnan(out.c[1]))) &&
        ((!std::isinf(out.c[2])) && (!std::isnan(out.c[2])))) {
      valid = true;
      for (int i{0}; i < 18; i++) {
        double d;
        d = out.Pdiag[i];
        valid = ((!std::isinf(d)) && (!std::isnan(d)) && valid);
      }
      if ((!valid) || (std::isinf(out.euler[0]) || std::isnan(out.euler[0])) ||
          (std::isinf(out.euler[1]) || std::isnan(out.euler[1])) ||
          (std::isinf(out.euler[2]) || std::isnan(out.euler[2])) ||
          (std::isinf(out.vel_body_water[0]) ||
           std::isnan(out.vel_body_water[0])) ||
          (std::isinf(out.vel_body_water[1]) ||
           std::isnan(out.vel_body_water[1])) ||
          (std::isinf(out.vel_body_water[2]) ||
           std::isnan(out.vel_body_water[2]))) {
        guard1 = true;
      }
    } else {
      guard1 = true;
    }
    if (guard1) {
      state.initialized = false;
      state.p[0] = 0.0;
      state.v[0] = 0.0;
      state.p[1] = 0.0;
      state.v[1] = 0.0;
      state.p[2] = 0.0;
      state.v[2] = 0.0;
      state.q[0] = 1.0;
      state.q[1] = 0.0;
      state.q[2] = 0.0;
      state.q[3] = 0.0;
      state.bg[0] = 0.0;
      state.ba[0] = 0.0;
      state.c[0] = 0.0;
      state.bg[1] = 0.0;
      state.ba[1] = 0.0;
      state.c[1] = 0.0;
      state.bg[2] = 0.0;
      state.ba[2] = 0.0;
      state.c[2] = 0.0;
      std::memset(&state.P[0], 0, 324U * sizeof(double));
      for (int i{0}; i < 7; i++) {
        state.last_seq[i] = 0U;
        state.have_seq[i] = false;
        state.last_ts[i] = 0.0;
        state.have_ts[i] = false;
        state.last_accept_t[i] = 0.0;
        state.have_accept_t[i] = false;
      }
      double s_ba[3];
      double s_bg[3];
      double s_c[3];
      double s_p[3];
      double s_v[3];
      state.est_seq = 0U;
      s_p[0] = 0.0;
      s_v[0] = 0.0;
      s_bg[0] = 0.0;
      s_ba[0] = 0.0;
      s_c[0] = 0.0;
      s_p[1] = 0.0;
      s_v[1] = 0.0;
      s_bg[1] = 0.0;
      s_ba[1] = 0.0;
      s_c[1] = 0.0;
      s_p[2] = 0.0;
      s_v[2] = 0.0;
      s_bg[2] = 0.0;
      s_ba[2] = 0.0;
      s_c[2] = 0.0;
      std::memset(&s_P[0], 0, 324U * sizeof(double));
      nav_fill_out(false, s_p, s_v, s_q, s_bg, s_ba, s_c, s_P, false, 65536U,
                   out);
    }
  }
}

//
// Arguments    : bool state_initialized
//                const double state_p[3]
//                const double state_v[3]
//                const double state_q[4]
//                const double state_bg[3]
//                const double state_ba[3]
//                const double state_c[3]
//                const double state_P[324]
//                bool valid
//                unsigned int hb
//                c_struct_T &out
// Return Type  : void
//
static void nav_fill_out(bool state_initialized, const double state_p[3],
                         const double state_v[3], const double state_q[4],
                         const double state_bg[3], const double state_ba[3],
                         const double state_c[3], const double state_P[324],
                         bool valid, unsigned int hb, c_struct_T &out)
{
  double Rbn[9];
  double Rbn_tmp;
  double b_Rbn_tmp;
  double c_Rbn_tmp;
  double d_Rbn_tmp;
  double r31;
  double wv_idx_1;
  double wv_idx_2;
  wv_idx_2 = state_q[3] * state_q[3];
  Rbn_tmp = state_q[2] * state_q[2];
  Rbn[0] = 1.0 - 2.0 * (Rbn_tmp + wv_idx_2);
  r31 = state_q[1] * state_q[2];
  wv_idx_1 = state_q[0] * state_q[3];
  Rbn[3] = 2.0 * (r31 - wv_idx_1);
  b_Rbn_tmp = state_q[1] * state_q[3];
  c_Rbn_tmp = state_q[0] * state_q[2];
  Rbn[6] = 2.0 * (b_Rbn_tmp + c_Rbn_tmp);
  Rbn[1] = 2.0 * (r31 + wv_idx_1);
  d_Rbn_tmp = state_q[1] * state_q[1];
  Rbn[4] = 1.0 - 2.0 * (d_Rbn_tmp + wv_idx_2);
  r31 = state_q[2] * state_q[3];
  wv_idx_1 = state_q[0] * state_q[1];
  Rbn[7] = 2.0 * (r31 - wv_idx_1);
  Rbn[2] = 2.0 * (b_Rbn_tmp - c_Rbn_tmp);
  Rbn[5] = 2.0 * (r31 + wv_idx_1);
  Rbn[8] = 1.0 - 2.0 * (d_Rbn_tmp + Rbn_tmp);
  r31 = Rbn[2];
  if (Rbn[2] > 1.0) {
    r31 = 1.0;
  }
  if (r31 < -1.0) {
    r31 = -1.0;
  }
  out.euler[0] = coder::b_atan2(Rbn[5], Rbn[8]);
  out.euler[1] = -std::asin(r31);
  out.euler[2] = coder::b_atan2(Rbn[1], Rbn[0]);
  r31 = state_v[0] - state_c[0];
  wv_idx_1 = state_v[1] - state_c[1];
  wv_idx_2 = state_v[2] - state_c[2];
  for (int i{0}; i < 3; i++) {
    out.vel_body_water[i] = (Rbn[3 * i] * r31 + Rbn[3 * i + 1] * wv_idx_1) +
                            Rbn[3 * i + 2] * wv_idx_2;
  }
  for (int i{0}; i < 18; i++) {
    out.Pdiag[i] = state_P[i + 18 * i];
  }
  out.p[0] = state_p[0];
  out.v[0] = state_v[0];
  out.p[1] = state_p[1];
  out.v[1] = state_v[1];
  out.p[2] = state_p[2];
  out.v[2] = state_v[2];
  out.q[0] = state_q[0];
  out.q[1] = state_q[1];
  out.q[2] = state_q[2];
  out.q[3] = state_q[3];
  out.bg[0] = state_bg[0];
  out.ba[0] = state_ba[0];
  out.c[0] = state_c[0];
  out.bg[1] = state_bg[1];
  out.ba[1] = state_ba[1];
  out.c[1] = state_c[1];
  out.bg[2] = state_bg[2];
  out.ba[2] = state_ba[2];
  out.c[2] = state_c[2];
  out.initialized = state_initialized;
  out.valid = valid;
  out.health_bits = hb;
}

//
// Arguments    : double params_g_ned
//                const double params_P0_p[3]
//                double params_P0_p_abs
//                const double params_P0_v[3]
//                const double params_P0_th[3]
//                const double params_P0_bg[3]
//                const double params_P0_ba[3]
//                const double params_P0_c[3]
//                double params_tol_pair
//                struct12_T &state
//                const struct16_T &in
//                bool &valid
// Return Type  : unsigned int
//
static unsigned int
nav_op_initialize(double params_g_ned, const double params_P0_p[3],
                  double params_P0_p_abs, const double params_P0_v[3],
                  const double params_P0_th[3], const double params_P0_bg[3],
                  const double params_P0_ba[3], const double params_P0_c[3],
                  double params_tol_pair, struct12_T &state,
                  const struct16_T &in, bool &valid)
{
  double P[324];
  unsigned int hb;
  hb = 0U;
  valid = false;
  if (!in.sample_valid) {
    hb = 8U;
  } else if ((!std::isinf(in.t)) && (!std::isnan(in.t)) &&
             ((!std::isinf(in.init_gyro[0])) &&
              (!std::isnan(in.init_gyro[0]))) &&
             ((!std::isinf(in.init_gyro[1])) &&
              (!std::isnan(in.init_gyro[1]))) &&
             ((!std::isinf(in.init_gyro[2])) &&
              (!std::isnan(in.init_gyro[2]))) &&
             ((!std::isinf(in.init_accel[0])) &&
              (!std::isnan(in.init_accel[0]))) &&
             ((!std::isinf(in.init_accel[1])) &&
              (!std::isnan(in.init_accel[1]))) &&
             ((!std::isinf(in.init_accel[2])) &&
              (!std::isnan(in.init_accel[2]))) &&
             ((!std::isinf(in.init_depth)) && (!std::isnan(in.init_depth))) &&
             ((!std::isinf(in.init_heading)) &&
              (!std::isnan(in.init_heading))) &&
             ((!std::isinf(in.init_ins_vel[0])) &&
              (!std::isnan(in.init_ins_vel[0]))) &&
             ((!std::isinf(in.init_ins_vel[1])) &&
              (!std::isnan(in.init_ins_vel[1]))) &&
             ((!std::isinf(in.init_ins_vel[2])) &&
              (!std::isnan(in.init_ins_vel[2]))) &&
             ((!std::isinf(in.init_timestamp[0])) &&
              (!std::isnan(in.init_timestamp[0]))) &&
             ((!std::isinf(in.init_timestamp[1])) &&
              (!std::isnan(in.init_timestamp[1]))) &&
             ((!std::isinf(in.init_timestamp[2])) &&
              (!std::isnan(in.init_timestamp[2]))) &&
             ((!std::isinf(in.init_timestamp[3])) &&
              (!std::isnan(in.init_timestamp[3]))) &&
             ((!std::isinf(in.init_timestamp[4])) &&
              (!std::isnan(in.init_timestamp[4])))) {
    double dpair;
    unsigned int u;
    unsigned int u1;
    unsigned int u2;
    unsigned int u3;
    unsigned int u4;
    dpair = rt_roundd_snf(in.init_seq[0]);
    if (dpair < 4.294967296E+9) {
      if (dpair >= 0.0) {
        u = static_cast<unsigned int>(dpair);
      } else {
        u = 0U;
      }
    } else if (dpair >= 4.294967296E+9) {
      u = MAX_uint32_T;
    } else {
      u = 0U;
    }
    dpair = rt_roundd_snf(in.init_seq[1]);
    if (dpair < 4.294967296E+9) {
      if (dpair >= 0.0) {
        u1 = static_cast<unsigned int>(dpair);
      } else {
        u1 = 0U;
      }
    } else if (dpair >= 4.294967296E+9) {
      u1 = MAX_uint32_T;
    } else {
      u1 = 0U;
    }
    dpair = rt_roundd_snf(in.init_seq[2]);
    if (dpair < 4.294967296E+9) {
      if (dpair >= 0.0) {
        u2 = static_cast<unsigned int>(dpair);
      } else {
        u2 = 0U;
      }
    } else if (dpair >= 4.294967296E+9) {
      u2 = MAX_uint32_T;
    } else {
      u2 = 0U;
    }
    dpair = rt_roundd_snf(in.init_seq[3]);
    if (dpair < 4.294967296E+9) {
      if (dpair >= 0.0) {
        u3 = static_cast<unsigned int>(dpair);
      } else {
        u3 = 0U;
      }
    } else if (dpair >= 4.294967296E+9) {
      u3 = MAX_uint32_T;
    } else {
      u3 = 0U;
    }
    dpair = rt_roundd_snf(in.init_seq[4]);
    if (dpair < 4.294967296E+9) {
      if (dpair >= 0.0) {
        u4 = static_cast<unsigned int>(dpair);
      } else {
        u4 = 0U;
      }
    } else if (dpair >= 4.294967296E+9) {
      u4 = MAX_uint32_T;
    } else {
      u4 = 0U;
    }
    if ((u == 0U) || (u1 == 0U) || (u2 == 0U) || (u3 == 0U) || (u4 == 0U)) {
      hb = 2048U;
    } else {
      dpair = in.init_timestamp[0] - in.init_timestamp[1];
      if (dpair < 0.0) {
        dpair = -dpair;
      }
      if (dpair > params_tol_pair) {
        hb = 8192U;
      } else {
        double qn[4];
        double acc1;
        double b_qn_tmp;
        double cp;
        double cr;
        double cy;
        double psi0;
        double qn_tmp;
        double sr;
        acc1 = in.init_accel[0] / params_g_ned;
        if (acc1 > 1.0) {
          acc1 = 1.0;
        }
        if (acc1 < -1.0) {
          acc1 = -1.0;
        }
        psi0 = coder::internal::scalar::c_mod(in.init_heading +
                                              3.1415926535897931) -
               3.1415926535897931;
        if ((psi0 == -3.1415926535897931) && (in.init_heading > 0.0)) {
          psi0 = 3.1415926535897931;
        }
        dpair = coder::b_atan2(-in.init_accel[1], -in.init_accel[2]) / 2.0;
        cr = std::cos(dpair);
        sr = std::sin(dpair);
        dpair = std::asin(acc1) / 2.0;
        cp = std::cos(dpair);
        acc1 = std::sin(dpair);
        dpair = psi0 / 2.0;
        cy = std::cos(dpair);
        psi0 = std::sin(dpair);
        qn_tmp = cr * cp;
        b_qn_tmp = sr * acc1;
        qn[0] = qn_tmp * cy + b_qn_tmp * psi0;
        acc1 *= cr;
        dpair = sr * cp;
        qn[1] = dpair * cy - acc1 * psi0;
        qn[2] = acc1 * cy + dpair * psi0;
        qn[3] = qn_tmp * psi0 - b_qn_tmp * cy;
        quat_norm_local(qn);
        std::memset(&P[0], 0, 324U * sizeof(double));
        if (in.abs_position_present) {
          P[0] = params_P0_p_abs;
          P[19] = params_P0_p_abs;
        } else {
          P[0] = params_P0_p[0];
          P[19] = params_P0_p[1];
        }
        P[38] = params_P0_p[2];
        P[57] = params_P0_v[0];
        P[76] = params_P0_v[1];
        P[95] = params_P0_v[2];
        P[114] = params_P0_th[0];
        P[133] = params_P0_th[1];
        P[152] = params_P0_th[2];
        P[171] = params_P0_bg[0];
        P[190] = params_P0_bg[1];
        P[209] = params_P0_bg[2];
        P[228] = params_P0_ba[0];
        P[247] = params_P0_ba[1];
        P[266] = params_P0_ba[2];
        P[285] = params_P0_c[0];
        P[304] = params_P0_c[1];
        P[323] = params_P0_c[2];
        if ((!std::isinf(qn[0])) && (!std::isnan(qn[0])) &&
            ((!std::isinf(qn[1])) && (!std::isnan(qn[1]))) &&
            ((!std::isinf(qn[2])) && (!std::isnan(qn[2]))) &&
            ((!std::isinf(qn[3])) && (!std::isnan(qn[3])))) {
          bool ok;
          ok = true;
          for (int i{0}; i < 18; i++) {
            for (int j{0}; j < 18; j++) {
              dpair = P[i + 18 * j];
              ok = ((!std::isinf(dpair)) && (!std::isnan(dpair)) && ok);
            }
          }
          if (ok) {
            for (int i{0}; i < 7; i++) {
              state.last_seq[i] = 0U;
              state.have_seq[i] = false;
              state.last_ts[i] = 0.0;
              state.have_ts[i] = false;
              state.last_accept_t[i] = 0.0;
              state.have_accept_t[i] = false;
            }
            state.last_seq[0] = u;
            state.last_seq[1] = u1;
            state.last_seq[2] = u2;
            state.last_seq[3] = u3;
            state.last_seq[4] = u4;
            state.have_seq[0] = true;
            state.have_seq[1] = true;
            state.have_seq[2] = true;
            state.have_seq[3] = true;
            state.have_seq[4] = true;
            state.last_ts[0] = in.init_timestamp[0];
            state.last_ts[1] = in.init_timestamp[1];
            state.last_ts[2] = in.init_timestamp[2];
            state.last_ts[3] = in.init_timestamp[3];
            state.last_ts[4] = in.init_timestamp[4];
            state.have_ts[0] = true;
            state.have_ts[1] = true;
            state.have_ts[2] = true;
            state.have_ts[3] = true;
            state.have_ts[4] = true;
            state.last_accept_t[0] = in.t;
            state.last_accept_t[1] = in.t;
            state.last_accept_t[2] = in.t;
            state.last_accept_t[3] = in.t;
            state.last_accept_t[4] = in.t;
            state.have_accept_t[0] = true;
            state.have_accept_t[1] = true;
            state.have_accept_t[2] = true;
            state.have_accept_t[3] = true;
            state.have_accept_t[4] = true;
            state.initialized = true;
            state.p[0] = 0.0;
            state.v[0] = in.init_ins_vel[0];
            state.p[1] = 0.0;
            state.v[1] = in.init_ins_vel[1];
            state.p[2] = in.init_depth;
            state.v[2] = in.init_ins_vel[2];
            state.q[0] = qn[0];
            state.q[1] = qn[1];
            state.q[2] = qn[2];
            state.q[3] = qn[3];
            state.bg[0] = 0.0;
            state.ba[0] = 0.0;
            state.c[0] = 0.0;
            state.bg[1] = 0.0;
            state.ba[1] = 0.0;
            state.c[1] = 0.0;
            state.bg[2] = 0.0;
            state.ba[2] = 0.0;
            state.c[2] = 0.0;
            std::copy(&P[0], &P[324], &state.P[0]);
            state.est_seq = 1U;
            valid = true;
          } else {
            hb = 65536U;
          }
        } else {
          hb = 65536U;
        }
      }
    }
  } else {
    hb = 16U;
  }
  return hb;
}

//
// Arguments    : double params_g_ned
//                double params_sigma_p
//                double params_sigma_a
//                double params_sigma_g
//                double params_sigma_bg
//                double params_sigma_ba
//                double params_sigma_c
//                double params_dt_prop_max
//                double params_dt_prop_sub
//                double params_n_sub_max
//                double params_tol_time
//                double params_tol_pair
//                struct12_T &state
//                const struct16_T &in
//                bool &valid
// Return Type  : unsigned int
//
static unsigned int nav_op_propagate(
    double params_g_ned, double params_sigma_p, double params_sigma_a,
    double params_sigma_g, double params_sigma_bg, double params_sigma_ba,
    double params_sigma_c, double params_dt_prop_max, double params_dt_prop_sub,
    double params_n_sub_max, double params_tol_time, double params_tol_pair,
    struct12_T &state, const struct16_T &in, bool &valid)
{
  double F[324];
  double P[324];
  double Phi[324];
  double b_Phi[324];
  double c_Phi[324];
  double R[9];
  double b_b[9];
  double a[3];
  double f[3];
  unsigned int hb;
  hb = 0U;
  valid = false;
  if (!state.initialized) {
    hb = 2U;
  } else if (!in.sample_valid) {
    hb = 8U;
  } else if ((!std::isinf(in.t)) && (!std::isnan(in.t)) &&
             ((!std::isinf(in.gyro[0])) && (!std::isnan(in.gyro[0]))) &&
             ((!std::isinf(in.gyro[1])) && (!std::isnan(in.gyro[1]))) &&
             ((!std::isinf(in.gyro[2])) && (!std::isnan(in.gyro[2]))) &&
             ((!std::isinf(in.accel[0])) && (!std::isnan(in.accel[0]))) &&
             ((!std::isinf(in.accel[1])) && (!std::isnan(in.accel[1]))) &&
             ((!std::isinf(in.accel[2])) && (!std::isnan(in.accel[2]))) &&
             ((!std::isinf(in.gyro_timestamp)) &&
              (!std::isnan(in.gyro_timestamp))) &&
             ((!std::isinf(in.accel_timestamp)) &&
              (!std::isnan(in.accel_timestamp)))) {
    if ((!state.have_seq[0]) || (!state.have_seq[1]) ||
        (in.gyro_seq <= state.last_seq[0]) ||
        (in.accel_seq <= state.last_seq[1])) {
      hb = 2048U;
    } else if ((!state.have_ts[0]) || (!state.have_ts[1]) ||
               (in.gyro_timestamp <= state.last_ts[0] + params_tol_time) ||
               (in.accel_timestamp <= state.last_ts[1] + params_tol_time)) {
      hb = 4096U;
    } else {
      double dpair;
      dpair = in.gyro_timestamp - in.accel_timestamp;
      if (dpair < 0.0) {
        dpair = -dpair;
      }
      if (dpair > params_tol_pair) {
        hb = 8192U;
      } else {
        dpair = in.gyro_timestamp - state.last_ts[0];
        if ((dpair <= 0.0) || (dpair > params_dt_prop_max)) {
          hb = 16384U;
        } else {
          double nsub;
          nsub = 1.0;
          if (dpair > params_dt_prop_sub) {
            nsub = std::ceil(dpair / params_dt_prop_sub);
          }
          if (nsub > params_n_sub_max) {
            hb = 16384U;
          } else {
            double q[4];
            double dt_sub;
            double p_idx_0;
            double p_idx_1;
            double p_idx_2;
            double v_idx_0;
            double v_idx_1;
            double v_idx_2;
            dt_sub = dpair / nsub;
            p_idx_0 = state.p[0];
            v_idx_0 = state.v[0];
            p_idx_1 = state.p[1];
            v_idx_1 = state.v[1];
            p_idx_2 = state.p[2];
            v_idx_2 = state.v[2];
            q[0] = state.q[0];
            q[1] = state.q[1];
            q[2] = state.q[2];
            q[3] = state.q[3];
            std::copy(&state.P[0], &state.P[324], &P[0]);
            for (int sstep{0}; sstep < 5; sstep++) {
              if (static_cast<double>(sstep) + 1.0 <= nsub) {
                double y_tmp[324];
                double F_tmp[9];
                double b_R[9];
                double R_tmp;
                double d;
                double d1;
                double d2;
                double d3;
                double sa2;
                double sba2;
                double sbg2;
                double sc2;
                double sg2;
                double w_idx_0;
                double w_idx_1;
                double w_idx_2;
                int b_F_tmp;
                int c_F_tmp;
                w_idx_0 = in.gyro[0] - state.bg[0];
                w_idx_1 = in.gyro[1] - state.bg[1];
                w_idx_2 = in.gyro[2] - state.bg[2];
                f[0] = in.accel[0] - state.ba[0];
                f[1] = in.accel[1] - state.ba[1];
                f[2] = in.accel[2] - state.ba[2];
                d = q[3];
                sg2 = q[3] * q[3];
                d1 = q[2];
                sba2 = q[2] * q[2];
                R[0] = 1.0 - 2.0 * (sba2 + sg2);
                d2 = q[1];
                dpair = q[1] * q[2];
                d3 = q[0];
                sa2 = q[0] * q[3];
                R[3] = 2.0 * (dpair - sa2);
                sc2 = q[1] * q[3];
                R_tmp = q[0] * q[2];
                R[6] = 2.0 * (sc2 + R_tmp);
                R[1] = 2.0 * (dpair + sa2);
                sbg2 = q[1] * q[1];
                R[4] = 1.0 - 2.0 * (sbg2 + sg2);
                dpair = q[2] * q[3];
                sa2 = q[0] * q[1];
                R[7] = 2.0 * (dpair - sa2);
                R[2] = 2.0 * (sc2 - R_tmp);
                R[5] = 2.0 * (dpair + sa2);
                R[8] = 1.0 - 2.0 * (sbg2 + sba2);
                std::memset(&a[0], 0, 3U * sizeof(double));
                sg2 = a[0];
                sbg2 = a[1];
                dpair = a[2];
                for (int i{0}; i < 3; i++) {
                  sa2 = f[i];
                  sg2 += R[3 * i] * sa2;
                  sbg2 += R[3 * i + 1] * sa2;
                  dpair += R[3 * i + 2] * sa2;
                }
                double b[4];
                a[2] = dpair + params_g_ned;
                dpair = dt_sub * dt_sub;
                p_idx_0 = (p_idx_0 + v_idx_0 * dt_sub) + 0.5 * sg2 * dpair;
                v_idx_0 += sg2 * dt_sub;
                a[0] = w_idx_0 * dt_sub;
                p_idx_1 = (p_idx_1 + v_idx_1 * dt_sub) + 0.5 * sbg2 * dpair;
                v_idx_1 += sbg2 * dt_sub;
                a[1] = w_idx_1 * dt_sub;
                p_idx_2 = (p_idx_2 + v_idx_2 * dt_sub) + 0.5 * a[2] * dpair;
                v_idx_2 += a[2] * dt_sub;
                a[2] = w_idx_2 * dt_sub;
                quat_from_rotvec_local(a, b);
                q[0] = ((d3 * b[0] - d2 * b[1]) - d1 * b[2]) - d * b[3];
                q[1] = ((d3 * b[1] + b[0] * d2) + d1 * b[3]) - b[2] * d;
                q[2] = ((d3 * b[2] - d2 * b[3]) + b[0] * d1) + b[1] * d;
                q[3] = ((d3 * b[3] + d2 * b[2]) - b[1] * d1) + b[0] * d;
                quat_norm_local(q);
                std::memset(&F[0], 0, 324U * sizeof(double));
                coder::eye(F_tmp);
                for (int i{0}; i < 3; i++) {
                  b_F_tmp = 18 * (i + 3);
                  F[b_F_tmp] = F_tmp[3 * i];
                  F[b_F_tmp + 1] = F_tmp[3 * i + 1];
                  F[b_F_tmp + 2] = F_tmp[3 * i + 2];
                }
                std::memset(&b_b[0], 0, 9U * sizeof(double));
                b_b[3] = -f[2];
                b_b[6] = f[1];
                b_b[1] = f[2];
                b_b[7] = -f[0];
                b_b[2] = -f[1];
                b_b[5] = f[0];
                for (int i{0}; i < 9; i++) {
                  b_R[i] = -R[i];
                }
                for (int i{0}; i < 3; i++) {
                  b_F_tmp = 18 * (i + 6);
                  F[b_F_tmp + 3] = 0.0;
                  F[b_F_tmp + 4] = 0.0;
                  F[b_F_tmp + 5] = 0.0;
                  for (int j{0}; j < 3; j++) {
                    c_F_tmp = j + 3 * i;
                    dpair = b_b[c_F_tmp];
                    F[b_F_tmp + 3] += b_R[3 * j] * dpair;
                    F[b_F_tmp + 4] += b_R[3 * j + 1] * dpair;
                    F[b_F_tmp + 5] += b_R[3 * j + 2] * dpair;
                    F[(j + 18 * (i + 12)) + 3] = -R[c_F_tmp];
                  }
                }
                std::memset(&b_b[0], 0, 9U * sizeof(double));
                b_b[3] = -w_idx_2;
                b_b[6] = w_idx_1;
                b_b[1] = w_idx_2;
                b_b[7] = -w_idx_0;
                b_b[2] = -w_idx_1;
                b_b[5] = w_idx_0;
                for (int i{0}; i < 3; i++) {
                  int d_F_tmp;
                  c_F_tmp = 18 * (i + 6);
                  F[c_F_tmp + 6] = -b_b[3 * i];
                  d_F_tmp = 18 * (i + 9);
                  F[d_F_tmp + 6] = -F_tmp[3 * i];
                  b_F_tmp = 3 * i + 1;
                  F[c_F_tmp + 7] = -b_b[b_F_tmp];
                  F[d_F_tmp + 7] = -F_tmp[b_F_tmp];
                  b_F_tmp = 3 * i + 2;
                  F[c_F_tmp + 8] = -b_b[b_F_tmp];
                  F[d_F_tmp + 8] = -F_tmp[b_F_tmp];
                }
                for (int i{0}; i < 324; i++) {
                  F[i] *= dt_sub;
                }
                coder::b_eye(y_tmp);
                std::memset(&Phi[0], 0, 324U * sizeof(double));
                for (int i{0}; i < 18; i++) {
                  for (int j{0}; j < 18; j++) {
                    dpair = F[j + 18 * i];
                    for (int b_i{0}; b_i < 18; b_i++) {
                      b_F_tmp = b_i + 18 * i;
                      Phi[b_F_tmp] += F[b_i + 18 * j] * dpair;
                    }
                  }
                }
                for (int i{0}; i < 324; i++) {
                  Phi[i] = (y_tmp[i] + F[i]) + 0.5 * Phi[i];
                  F[i] = 0.0;
                }
                dpair = params_sigma_p * params_sigma_p;
                sa2 = params_sigma_a * params_sigma_a;
                sg2 = params_sigma_g * params_sigma_g;
                sbg2 = params_sigma_bg * params_sigma_bg;
                sba2 = params_sigma_ba * params_sigma_ba;
                sc2 = params_sigma_c * params_sigma_c;
                F[0] = dpair;
                F[19] = dpair;
                F[38] = dpair;
                F[57] = sa2;
                F[76] = sa2;
                F[95] = sa2;
                F[114] = sg2;
                F[133] = sg2;
                F[152] = sg2;
                F[171] = sbg2;
                F[190] = sbg2;
                F[209] = sbg2;
                F[228] = sba2;
                F[247] = sba2;
                F[266] = sba2;
                F[285] = sc2;
                F[304] = sc2;
                F[323] = sc2;
                std::memset(&b_Phi[0], 0, 324U * sizeof(double));
                std::memset(&c_Phi[0], 0, 324U * sizeof(double));
                for (int j{0}; j < 18; j++) {
                  for (int b_i{0}; b_i < 18; b_i++) {
                    b_F_tmp = b_i + 18 * j;
                    y_tmp[b_F_tmp] = Phi[j + 18 * b_i];
                    dpair = P[b_F_tmp];
                    sa2 = F[b_F_tmp];
                    for (int i{0}; i < 18; i++) {
                      sg2 = Phi[i + 18 * b_i];
                      b_F_tmp = i + 18 * j;
                      b_Phi[b_F_tmp] += sg2 * dpair;
                      c_Phi[b_F_tmp] += sg2 * sa2;
                    }
                  }
                }
                for (int j{0}; j < 18; j++) {
                  for (int b_i{0}; b_i < 18; b_i++) {
                    dpair = 0.0;
                    sa2 = 0.0;
                    for (int i{0}; i < 18; i++) {
                      sg2 = y_tmp[i + 18 * b_i];
                      b_F_tmp = j + 18 * i;
                      dpair += c_Phi[b_F_tmp] * sg2;
                      sa2 += b_Phi[b_F_tmp] * sg2;
                    }
                    b_F_tmp = j + 18 * b_i;
                    P[b_F_tmp] = sa2 + 0.5 * (dpair + F[b_F_tmp]) * dt_sub;
                  }
                }
                for (int i{0}; i < 18; i++) {
                  for (int j{0}; j < 18; j++) {
                    b_F_tmp = j + 18 * i;
                    c_Phi[b_F_tmp] = 0.5 * (P[b_F_tmp] + P[i + 18 * j]);
                  }
                }
                std::copy(&c_Phi[0], &c_Phi[324], &P[0]);
              }
            }
            if ((!std::isinf(p_idx_0)) && (!std::isnan(p_idx_0)) &&
                ((!std::isinf(p_idx_1)) && (!std::isnan(p_idx_1))) &&
                ((!std::isinf(p_idx_2)) && (!std::isnan(p_idx_2))) &&
                ((!std::isinf(v_idx_0)) && (!std::isnan(v_idx_0))) &&
                ((!std::isinf(v_idx_1)) && (!std::isnan(v_idx_1))) &&
                ((!std::isinf(v_idx_2)) && (!std::isnan(v_idx_2))) &&
                ((!std::isinf(q[0])) && (!std::isnan(q[0]))) &&
                ((!std::isinf(q[1])) && (!std::isnan(q[1]))) &&
                ((!std::isinf(q[2])) && (!std::isnan(q[2]))) &&
                ((!std::isinf(q[3])) && (!std::isnan(q[3]))) &&
                ((!std::isinf(state.bg[0])) && (!std::isnan(state.bg[0]))) &&
                ((!std::isinf(state.bg[1])) && (!std::isnan(state.bg[1]))) &&
                ((!std::isinf(state.bg[2])) && (!std::isnan(state.bg[2]))) &&
                ((!std::isinf(state.ba[0])) && (!std::isnan(state.ba[0]))) &&
                ((!std::isinf(state.ba[1])) && (!std::isnan(state.ba[1]))) &&
                ((!std::isinf(state.ba[2])) && (!std::isnan(state.ba[2]))) &&
                ((!std::isinf(state.c[0])) && (!std::isnan(state.c[0]))) &&
                ((!std::isinf(state.c[1])) && (!std::isnan(state.c[1]))) &&
                ((!std::isinf(state.c[2])) && (!std::isnan(state.c[2])))) {
              bool ok;
              ok = true;
              for (int i{0}; i < 18; i++) {
                for (int j{0}; j < 18; j++) {
                  dpair = P[i + 18 * j];
                  ok = ((!std::isinf(dpair)) && (!std::isnan(dpair)) && ok);
                }
              }
              if (ok) {
                unsigned int q0;
                unsigned int qY;
                state.p[0] = p_idx_0;
                state.v[0] = v_idx_0;
                state.p[1] = p_idx_1;
                state.v[1] = v_idx_1;
                state.p[2] = p_idx_2;
                state.v[2] = v_idx_2;
                state.q[0] = q[0];
                state.q[1] = q[1];
                state.q[2] = q[2];
                state.q[3] = q[3];
                std::copy(&P[0], &P[324], &state.P[0]);
                state.last_seq[0] = in.gyro_seq;
                state.last_seq[1] = in.accel_seq;
                state.have_seq[0] = true;
                state.have_seq[1] = true;
                state.last_ts[0] = in.gyro_timestamp;
                state.last_ts[1] = in.accel_timestamp;
                state.have_ts[0] = true;
                state.have_ts[1] = true;
                state.last_accept_t[0] = in.t;
                state.last_accept_t[1] = in.t;
                state.have_accept_t[0] = true;
                state.have_accept_t[1] = true;
                q0 = state.est_seq;
                qY = q0 + 1U;
                if (q0 + 1U < q0) {
                  qY = MAX_uint32_T;
                }
                state.est_seq = qY;
                valid = true;
              } else {
                hb = 65536U;
              }
            } else {
              hb = 65536U;
            }
          }
        }
      }
    }
  } else {
    hb = 16U;
  }
  return hb;
}

//
// Arguments    : double params_R_depth
//                double params_R_heading
//                const double params_R_ins[3]
//                const double params_R_dvl[3]
//                const double params_R_usbl[3]
//                double params_lat_depth
//                double params_lat_heading
//                double params_lat_ins
//                double params_lat_dvl
//                double params_lat_usbl
//                double params_q_min_frac
//                double params_q_floor
//                double params_nis_scale
//                double params_tol_time
//                struct12_T &state
//                const struct16_T &in
//                bool &valid
//                bool &fused
// Return Type  : unsigned int
//
static unsigned int
nav_op_update(double params_R_depth, double params_R_heading,
              const double params_R_ins[3], const double params_R_dvl[3],
              const double params_R_usbl[3], double params_lat_depth,
              double params_lat_heading, double params_lat_ins,
              double params_lat_dvl, double params_lat_usbl,
              double params_q_min_frac, double params_q_floor,
              double params_nis_scale, double params_tol_time,
              struct12_T &state, const struct16_T &in, bool &valid, bool &fused)
{
  static const signed char iv[324]{
      1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1};
  double IKH[324];
  double P[324];
  double H[54];
  double K[54];
  double b_H[54];
  double y_tmp[54];
  double dx[18];
  double Rbn[9];
  double Rm[9];
  double hx_tmp[9];
  double ba[3];
  double bg[3];
  double c[3];
  double dth[3];
  double v[3];
  unsigned int hb;
  bool ch_ok;
  hb = 0U;
  valid = false;
  fused = false;
  ch_ok = false;
  if ((in.channel == 3) || (in.channel == 4)) {
    ch_ok = (in.dim == 1);
  } else if ((in.channel == 5) || (in.channel == 6) || (in.channel == 7)) {
    ch_ok = (in.dim == 3);
  }
  if (!ch_ok) {
    hb = 32U;
  } else if (!in.present) {
    hb = 64U;
  } else if ((!in.packet_valid) || (in.status != 2)) {
    hb = 128U;
  } else {
    bool bfin;
    ch_ok = ((!std::isinf(in.value[0])) && (!std::isnan(in.value[0])));
    if ((in.dim == 3) &&
        ((!ch_ok) || (std::isinf(in.value[1]) || std::isnan(in.value[1])) ||
         (std::isinf(in.value[2]) || std::isnan(in.value[2])))) {
      ch_ok = false;
    }
    if ((!std::isinf(in.bound_lo[0])) && (!std::isnan(in.bound_lo[0])) &&
        ((!std::isinf(in.bound_hi[0])) && (!std::isnan(in.bound_hi[0])))) {
      bfin = true;
    } else {
      bfin = false;
    }
    if (in.dim == 3) {
      if (bfin &&
          ((!std::isinf(in.bound_lo[1])) && (!std::isnan(in.bound_lo[1]))) &&
          ((!std::isinf(in.bound_hi[1])) && (!std::isnan(in.bound_hi[1]))) &&
          ((!std::isinf(in.bound_lo[2])) && (!std::isnan(in.bound_lo[2]))) &&
          ((!std::isinf(in.bound_hi[2])) && (!std::isnan(in.bound_hi[2])))) {
        bfin = true;
      } else {
        bfin = false;
      }
    }
    if (ch_ok && ((!std::isinf(in.timestamp)) && (!std::isnan(in.timestamp))) &&
        ((!std::isinf(in.quality)) && (!std::isnan(in.quality))) &&
        ((!std::isinf(in.stale_age)) && (!std::isnan(in.stale_age))) &&
        ((!std::isinf(in.t)) && (!std::isnan(in.t))) &&
        ((!std::isinf(in.q_nom)) && (!std::isnan(in.q_nom))) &&
        ((!std::isinf(in.stale_limit_s)) && (!std::isnan(in.stale_limit_s))) &&
        bfin) {
      ch_ok = (in.bound_lo[0] <= in.bound_hi[0]);
      if ((in.dim == 3) && ((!ch_ok) || (!(in.bound_lo[1] <= in.bound_hi[1])) ||
                            (!(in.bound_lo[2] <= in.bound_hi[2])))) {
        ch_ok = false;
      }
      if (!ch_ok) {
        hb = 256U;
      } else {
        if ((in.value[0] < in.bound_lo[0] - 1.0E-9) ||
            (in.value[0] > in.bound_hi[0] + 1.0E-9)) {
          ch_ok = true;
        } else {
          ch_ok = false;
        }
        if (in.dim == 3) {
          if (ch_ok || (in.value[1] < in.bound_lo[1] - 1.0E-9) ||
              (in.value[1] > in.bound_hi[1] + 1.0E-9) ||
              (in.value[2] < in.bound_lo[2] - 1.0E-9) ||
              (in.value[2] > in.bound_hi[2] + 1.0E-9)) {
            ch_ok = true;
          } else {
            ch_ok = false;
          }
        }
        if (ch_ok) {
          hb = 256U;
        } else if (in.q_nom <= 0.0) {
          hb = 512U;
        } else if (in.quality <
                   params_q_min_frac * in.q_nom - params_tol_time) {
          hb = 512U;
        } else if ((in.stale_limit_s < 0.0) || (in.stale_age < 0.0)) {
          hb = 1024U;
        } else if (in.stale_age > in.stale_limit_s + params_tol_time) {
          hb = 1024U;
        } else {
          unsigned int last_seq;
          last_seq = 0U;
          if (state.have_seq[in.channel - 1]) {
            last_seq = state.last_seq[in.channel - 1];
          }
          if (in.seq <= last_seq) {
            hb = 2048U;
          } else if (state.have_ts[in.channel - 1] &&
                     (in.timestamp <=
                      state.last_ts[in.channel - 1] + params_tol_time)) {
            hb = 4096U;
          } else if (!state.initialized) {
            hb = 2U;
          } else {
            double Gr[324];
            double b_IKH[324];
            double nu[3];
            double Ssc;
            double age;
            double q_nom;
            double qs;
            int Gr_tmp;
            int IKH_tmp;
            bool guard1;
            bool guard2;
            age = 0.0;
            if (state.have_ts[0]) {
              age = state.last_ts[0] - in.timestamp;
              if (age < 0.0) {
                age = 0.0;
              }
            }
            q_nom = in.q_nom;
            if (!(in.q_nom > 2.2204460492503131E-16)) {
              q_nom = 2.2204460492503131E-16;
            }
            qs = in.quality / q_nom;
            if (qs < params_q_floor) {
              qs = params_q_floor;
            }
            std::memset(&H[0], 0, 54U * sizeof(double));
            std::memset(&Rm[0], 0, 9U * sizeof(double));
            quat2rot_local(state.q, Rbn);
            guard1 = false;
            guard2 = false;
            if (in.channel == 3) {
              H[6] = 1.0;
              nu[0] = in.value[0] - state.p[2];
              q_nom = params_lat_depth * age;
              Rm[0] = params_R_depth / qs + q_nom * q_nom;
              guard2 = true;
            } else if (in.channel == 4) {
              rot2euler_local(Rbn, v);
              q_nom = std::cos(v[1]);
              if (std::abs(q_nom) < 1.0E-6) {
                if (q_nom > 0.0) {
                  IKH_tmp = 1;
                } else if (q_nom < 0.0) {
                  IKH_tmp = -1;
                } else {
                  IKH_tmp = 1;
                }
                q_nom = 1.0E-6 * static_cast<double>(IKH_tmp);
              }
              H[21] = std::sin(v[0]) / q_nom;
              H[24] = std::cos(v[0]) / q_nom;
              q_nom = in.value[0] - v[2];
              Ssc = coder::internal::scalar::c_mod(q_nom + 3.1415926535897931) -
                    3.1415926535897931;
              nu[0] = Ssc;
              if ((Ssc == -3.1415926535897931) && (q_nom > 0.0)) {
                nu[0] = 3.1415926535897931;
              }
              q_nom = params_lat_heading * age;
              Rm[0] = params_R_heading / qs + q_nom * q_nom;
              guard2 = true;
            } else {
              double d;
              double d1;
              if (in.channel == 5) {
                H[9] = 1.0;
                H[13] = 1.0;
                H[17] = 1.0;
                nu[0] = in.value[0] - state.v[0];
                nu[1] = in.value[1] - state.v[1];
                nu[2] = in.value[2] - state.v[2];
                q_nom = params_lat_ins * age;
                q_nom *= q_nom;
                Rm[0] = params_R_ins[0] / qs + q_nom;
                Rm[4] = params_R_ins[1] / qs + q_nom;
                Rm[8] = params_R_ins[2] / qs + q_nom;
              } else if (in.channel == 6) {
                v[0] = state.v[0] - state.c[0];
                v[1] = state.v[1] - state.c[1];
                v[2] = state.v[2] - state.c[2];
                std::memset(&dth[0], 0, 3U * sizeof(double));
                q_nom = dth[0];
                Ssc = dth[1];
                d = dth[2];
                for (int i{0}; i < 3; i++) {
                  double d2;
                  d1 = Rbn[i];
                  d2 = v[i];
                  q_nom += d1 * d2;
                  IKH_tmp = 3 * (i + 3);
                  H[IKH_tmp] = d1;
                  Gr_tmp = 3 * (i + 15);
                  H[Gr_tmp] = -d1;
                  d1 = Rbn[i + 3];
                  Ssc += d1 * d2;
                  H[IKH_tmp + 1] = d1;
                  H[Gr_tmp + 1] = -d1;
                  d1 = Rbn[i + 6];
                  d += d1 * d2;
                  H[IKH_tmp + 2] = d1;
                  H[Gr_tmp + 2] = -d1;
                }
                dth[2] = d;
                dth[1] = Ssc;
                dth[0] = q_nom;
                skew_local(dth, &H[18]);
                nu[0] = in.value[0] - q_nom;
                nu[1] = in.value[1] - Ssc;
                nu[2] = in.value[2] - d;
                q_nom = params_lat_dvl * age;
                q_nom *= q_nom;
                Rm[0] = params_R_dvl[0] / qs + q_nom;
                Rm[4] = params_R_dvl[1] / qs + q_nom;
                Rm[8] = params_R_dvl[2] / qs + q_nom;
              } else {
                H[0] = 1.0;
                H[4] = 1.0;
                H[8] = 1.0;
                nu[0] = in.value[0] - state.p[0];
                nu[1] = in.value[1] - state.p[1];
                nu[2] = in.value[2] - state.p[2];
                q_nom = params_lat_usbl * age;
                q_nom *= q_nom;
                Rm[0] = params_R_usbl[0] / qs + q_nom;
                Rm[4] = params_R_usbl[1] / qs + q_nom;
                Rm[8] = params_R_usbl[2] / qs + q_nom;
              }
              for (int i{0}; i < 3; i++) {
                for (int b_i{0}; b_i < 18; b_i++) {
                  y_tmp[b_i + 18 * i] = H[i + 3 * b_i];
                }
              }
              std::memset(&b_H[0], 0, 54U * sizeof(double));
              for (int i{0}; i < 18; i++) {
                q_nom = b_H[3 * i];
                IKH_tmp = 3 * i + 1;
                Gr_tmp = 3 * i + 2;
                for (int b_i{0}; b_i < 18; b_i++) {
                  Ssc = state.P[b_i + 18 * i];
                  q_nom += H[3 * b_i] * Ssc;
                  b_H[IKH_tmp] += H[3 * b_i + 1] * Ssc;
                  b_H[Gr_tmp] += H[3 * b_i + 2] * Ssc;
                }
                b_H[3 * i] = q_nom;
              }
              for (int b_i{0}; b_i < 3; b_i++) {
                for (int i1{0}; i1 < 3; i1++) {
                  q_nom = 0.0;
                  for (int i{0}; i < 18; i++) {
                    q_nom += b_H[b_i + 3 * i] * y_tmp[i + 18 * i1];
                  }
                  IKH_tmp = b_i + 3 * i1;
                  Rbn[IKH_tmp] = q_nom + Rm[IKH_tmp];
                }
              }
              for (int i{0}; i < 3; i++) {
                hx_tmp[3 * i] = 0.5 * (Rbn[3 * i] + Rbn[i]);
                IKH_tmp = 3 * i + 1;
                hx_tmp[IKH_tmp] = 0.5 * (Rbn[IKH_tmp] + Rbn[i + 3]);
                IKH_tmp = 3 * i + 2;
                hx_tmp[IKH_tmp] = 0.5 * (Rbn[IKH_tmp] + Rbn[i + 6]);
              }
              if (!chol3_spd(hx_tmp)) {
                hb = 32768U;
              } else {
                std::copy(&hx_tmp[0], &hx_tmp[9], &Rbn[0]);
                ch_ok = inv3_fixed(Rbn, hx_tmp);
                if (!ch_ok) {
                  hb = 32768U;
                } else {
                  std::memset(&v[0], 0, 3U * sizeof(double));
                  q_nom = v[0];
                  Ssc = v[1];
                  d = v[2];
                  for (int i{0}; i < 3; i++) {
                    d1 = nu[i];
                    q_nom += hx_tmp[3 * i] * d1;
                    Ssc += hx_tmp[3 * i + 1] * d1;
                    d += hx_tmp[3 * i + 2] * d1;
                  }
                  q_nom = (nu[0] * q_nom + nu[1] * Ssc) + nu[2] * d;
                  if ((!std::isinf(q_nom)) && (!std::isnan(q_nom)) &&
                      (q_nom <= params_nis_scale * 3.0)) {
                    std::memset(&b_H[0], 0, 54U * sizeof(double));
                    for (int i{0}; i < 3; i++) {
                      for (int b_i{0}; b_i < 18; b_i++) {
                        q_nom = y_tmp[b_i + 18 * i];
                        for (int i1{0}; i1 < 18; i1++) {
                          IKH_tmp = i1 + 18 * i;
                          b_H[IKH_tmp] += state.P[i1 + 18 * b_i] * q_nom;
                        }
                      }
                    }
                    std::memset(&K[0], 0, 54U * sizeof(double));
                    std::memset(&dx[0], 0, 18U * sizeof(double));
                    for (int i1{0}; i1 < 3; i1++) {
                      for (int i{0}; i < 3; i++) {
                        q_nom = hx_tmp[i + 3 * i1];
                        for (int b_i{0}; b_i < 18; b_i++) {
                          IKH_tmp = b_i + 18 * i1;
                          K[IKH_tmp] += b_H[b_i + 18 * i] * q_nom;
                        }
                      }
                      for (int i{0}; i < 18; i++) {
                        dx[i] += K[i + 18 * i1] * nu[i1];
                      }
                    }
                    coder::b_eye(Gr);
                    for (int i{0}; i < 18; i++) {
                      q_nom = K[i];
                      Ssc = K[i + 18];
                      d = K[i + 36];
                      for (int b_i{0}; b_i < 18; b_i++) {
                        IKH_tmp = i + 18 * b_i;
                        b_IKH[IKH_tmp] =
                            Gr[IKH_tmp] -
                            ((q_nom * H[3 * b_i] + Ssc * H[3 * b_i + 1]) +
                             d * H[3 * b_i + 2]);
                      }
                    }
                    std::memset(&IKH[0], 0, 324U * sizeof(double));
                    for (int i{0}; i < 18; i++) {
                      for (int b_i{0}; b_i < 18; b_i++) {
                        q_nom = state.P[b_i + 18 * i];
                        for (int i1{0}; i1 < 18; i1++) {
                          IKH_tmp = i1 + 18 * i;
                          IKH[IKH_tmp] += b_IKH[i1 + 18 * b_i] * q_nom;
                        }
                      }
                    }
                    std::memset(&y_tmp[0], 0, 54U * sizeof(double));
                    for (int i{0}; i < 3; i++) {
                      for (int b_i{0}; b_i < 3; b_i++) {
                        q_nom = Rm[b_i + 3 * i];
                        for (int i1{0}; i1 < 18; i1++) {
                          IKH_tmp = i1 + 18 * i;
                          y_tmp[IKH_tmp] += K[i1 + 18 * b_i] * q_nom;
                        }
                      }
                    }
                    std::memset(&P[0], 0, 324U * sizeof(double));
                    for (int i{0}; i < 18; i++) {
                      for (int b_i{0}; b_i < 18; b_i++) {
                        q_nom = b_IKH[i + 18 * b_i];
                        for (int i1{0}; i1 < 18; i1++) {
                          IKH_tmp = i1 + 18 * i;
                          P[IKH_tmp] += IKH[i1 + 18 * b_i] * q_nom;
                        }
                      }
                    }
                    std::memset(&IKH[0], 0, 324U * sizeof(double));
                    for (int i{0}; i < 18; i++) {
                      for (int b_i{0}; b_i < 3; b_i++) {
                        q_nom = K[i + 18 * b_i];
                        for (int i1{0}; i1 < 18; i1++) {
                          IKH_tmp = i1 + 18 * i;
                          IKH[IKH_tmp] += y_tmp[i1 + 18 * b_i] * q_nom;
                        }
                      }
                    }
                    for (int i{0}; i < 324; i++) {
                      P[i] += IKH[i];
                    }
                    guard1 = true;
                  } else {
                    hb = 32768U;
                  }
                }
              }
            }
            if (guard2) {
              double Ht[18];
              std::memset(&dx[0], 0, 18U * sizeof(double));
              for (int i{0}; i < 18; i++) {
                q_nom = H[3 * i];
                Ht[i] = q_nom;
                for (int b_i{0}; b_i < 18; b_i++) {
                  dx[b_i] += state.P[b_i + 18 * i] * q_nom;
                }
              }
              Ssc = 0.0;
              for (int i{0}; i < 18; i++) {
                Ssc += Ht[i] * dx[i];
              }
              Ssc += Rm[0];
              if ((!std::isinf(Ssc)) && (!std::isnan(Ssc)) && (Ssc > 1.0E-18)) {
                q_nom = nu[0] * nu[0] / Ssc;
                if ((!std::isinf(q_nom)) && (!std::isnan(q_nom)) &&
                    (q_nom <= params_nis_scale)) {
                  double Ks[18];
                  for (int i{0}; i < 18; i++) {
                    q_nom = dx[i] / Ssc;
                    Ks[i] = q_nom;
                    dx[i] = q_nom * nu[0];
                  }
                  coder::b_eye(Gr);
                  for (int i{0}; i < 18; i++) {
                    for (int b_i{0}; b_i < 18; b_i++) {
                      IKH_tmp = b_i + 18 * i;
                      b_IKH[IKH_tmp] = Gr[IKH_tmp] - Ks[b_i] * Ht[i];
                    }
                  }
                  std::memset(&IKH[0], 0, 324U * sizeof(double));
                  for (int i{0}; i < 18; i++) {
                    for (int b_i{0}; b_i < 18; b_i++) {
                      q_nom = state.P[b_i + 18 * i];
                      for (int i1{0}; i1 < 18; i1++) {
                        IKH_tmp = i1 + 18 * i;
                        IKH[IKH_tmp] += b_IKH[i1 + 18 * b_i] * q_nom;
                      }
                    }
                  }
                  std::memset(&P[0], 0, 324U * sizeof(double));
                  for (int i{0}; i < 18; i++) {
                    for (int b_i{0}; b_i < 18; b_i++) {
                      q_nom = b_IKH[i + 18 * b_i];
                      for (int i1{0}; i1 < 18; i1++) {
                        IKH_tmp = i1 + 18 * i;
                        P[IKH_tmp] += IKH[i1 + 18 * b_i] * q_nom;
                      }
                    }
                  }
                  for (int i{0}; i < 18; i++) {
                    for (int b_i{0}; b_i < 18; b_i++) {
                      IKH[b_i + 18 * i] = Ks[b_i] * Rm[0] * Ks[i];
                    }
                  }
                  for (int i{0}; i < 324; i++) {
                    P[i] += IKH[i];
                  }
                  guard1 = true;
                } else {
                  hb = 32768U;
                }
              } else {
                hb = 32768U;
              }
            }
            if (guard1) {
              for (int i{0}; i < 18; i++) {
                for (int b_i{0}; b_i < 18; b_i++) {
                  IKH_tmp = b_i + 18 * i;
                  IKH[IKH_tmp] = 0.5 * (P[IKH_tmp] + P[i + 18 * b_i]);
                }
              }
              std::copy(&IKH[0], &IKH[324], &P[0]);
              if (all_finite18(dx) && all_finite18x18(IKH)) {
                ch_ok = true;
              } else {
                ch_ok = false;
              }
              if (ch_ok) {
                double dv[4];
                double q[4];
                nu[0] = state.p[0] + dx[0];
                nu[1] = state.p[1] + dx[1];
                nu[2] = state.p[2] + dx[2];
                v[0] = state.v[0] + dx[3];
                v[1] = state.v[1] + dx[4];
                v[2] = state.v[2] + dx[5];
                dth[0] = dx[6];
                dth[1] = dx[7];
                dth[2] = dx[8];
                quat_from_rotvec_local(dth, dv);
                quat_mul_local(state.q, dv, q);
                quat_norm_local(q);
                bg[0] = state.bg[0] + dx[9];
                bg[1] = state.bg[1] + dx[10];
                bg[2] = state.bg[2] + dx[11];
                ba[0] = state.ba[0] + dx[12];
                ba[1] = state.ba[1] + dx[13];
                ba[2] = state.ba[2] + dx[14];
                c[0] = state.c[0] + dx[15];
                c[1] = state.c[1] + dx[16];
                c[2] = state.c[2] + dx[17];
                for (int i{0}; i < 324; i++) {
                  Gr[i] = iv[i];
                }
                coder::eye(Rbn);
                skew_local(dth, hx_tmp);
                for (int i{0}; i < 3; i++) {
                  Gr_tmp = 18 * (i + 6);
                  Gr[Gr_tmp + 6] = Rbn[3 * i] - 0.5 * hx_tmp[3 * i];
                  IKH_tmp = 3 * i + 1;
                  Gr[Gr_tmp + 7] = Rbn[IKH_tmp] - 0.5 * hx_tmp[IKH_tmp];
                  IKH_tmp = 3 * i + 2;
                  Gr[Gr_tmp + 8] = Rbn[IKH_tmp] - 0.5 * hx_tmp[IKH_tmp];
                }
                std::memset(&IKH[0], 0, 324U * sizeof(double));
                for (int i{0}; i < 18; i++) {
                  for (int b_i{0}; b_i < 18; b_i++) {
                    q_nom = P[b_i + 18 * i];
                    for (int i1{0}; i1 < 18; i1++) {
                      IKH_tmp = i1 + 18 * i;
                      IKH[IKH_tmp] += Gr[i1 + 18 * b_i] * q_nom;
                    }
                  }
                }
                std::memset(&P[0], 0, 324U * sizeof(double));
                for (int i{0}; i < 18; i++) {
                  for (int b_i{0}; b_i < 18; b_i++) {
                    q_nom = Gr[i + 18 * b_i];
                    for (int i1{0}; i1 < 18; i1++) {
                      IKH_tmp = i1 + 18 * i;
                      P[IKH_tmp] += IKH[i1 + 18 * b_i] * q_nom;
                    }
                  }
                }
                for (int i{0}; i < 18; i++) {
                  for (int b_i{0}; b_i < 18; b_i++) {
                    IKH_tmp = b_i + 18 * i;
                    IKH[IKH_tmp] = 0.5 * (P[IKH_tmp] + P[i + 18 * b_i]);
                  }
                }
                std::copy(&IKH[0], &IKH[324], &P[0]);
                if (all_finite3(nu) && all_finite3(v) && all_finite4(q) &&
                    all_finite3(bg) && all_finite3(ba) && all_finite3(c) &&
                    all_finite18x18(IKH)) {
                  unsigned int qY;
                  state.p[0] = nu[0];
                  state.v[0] = v[0];
                  state.p[1] = nu[1];
                  state.v[1] = v[1];
                  state.p[2] = nu[2];
                  state.v[2] = v[2];
                  state.q[0] = q[0];
                  state.q[1] = q[1];
                  state.q[2] = q[2];
                  state.q[3] = q[3];
                  state.bg[0] = bg[0];
                  state.ba[0] = ba[0];
                  state.c[0] = c[0];
                  state.bg[1] = bg[1];
                  state.ba[1] = ba[1];
                  state.c[1] = c[1];
                  state.bg[2] = bg[2];
                  state.ba[2] = ba[2];
                  state.c[2] = c[2];
                  std::copy(&P[0], &P[324], &state.P[0]);
                  state.last_seq[in.channel - 1] = in.seq;
                  state.have_seq[in.channel - 1] = true;
                  state.last_ts[in.channel - 1] = in.timestamp;
                  state.have_ts[in.channel - 1] = true;
                  state.last_accept_t[in.channel - 1] = in.t;
                  state.have_accept_t[in.channel - 1] = true;
                  last_seq = state.est_seq;
                  qY = last_seq + 1U;
                  if (last_seq + 1U < last_seq) {
                    qY = MAX_uint32_T;
                  }
                  state.est_seq = qY;
                  valid = true;
                  fused = true;
                } else {
                  ch_ok = false;
                }
              }
              if (!ch_ok) {
                hb = 65536U;
              }
            }
          }
        }
      }
    } else {
      hb = 16U;
    }
  }
  return hb;
}

//
// Arguments    : const double state_p[3]
//                const double state_v[3]
//                const double state_q[4]
//                const double state_bg[3]
//                const double state_ba[3]
//                const double state_c[3]
//                const double state_P[324]
//                const double state_last_ts[7]
//                const double state_last_accept_t[7]
// Return Type  : bool
//
static bool
nav_state_is_finite(const double state_p[3], const double state_v[3],
                    const double state_q[4], const double state_bg[3],
                    const double state_ba[3], const double state_c[3],
                    const double state_P[324], const double state_last_ts[7],
                    const double state_last_accept_t[7])
{
  bool ok;
  if ((!std::isinf(state_p[0])) && (!std::isnan(state_p[0])) &&
      ((!std::isinf(state_p[1])) && (!std::isnan(state_p[1]))) &&
      ((!std::isinf(state_p[2])) && (!std::isnan(state_p[2]))) &&
      ((!std::isinf(state_v[0])) && (!std::isnan(state_v[0]))) &&
      ((!std::isinf(state_v[1])) && (!std::isnan(state_v[1]))) &&
      ((!std::isinf(state_v[2])) && (!std::isnan(state_v[2]))) &&
      ((!std::isinf(state_q[0])) && (!std::isnan(state_q[0]))) &&
      ((!std::isinf(state_q[1])) && (!std::isnan(state_q[1]))) &&
      ((!std::isinf(state_q[2])) && (!std::isnan(state_q[2]))) &&
      ((!std::isinf(state_q[3])) && (!std::isnan(state_q[3]))) &&
      ((!std::isinf(state_bg[0])) && (!std::isnan(state_bg[0]))) &&
      ((!std::isinf(state_bg[1])) && (!std::isnan(state_bg[1]))) &&
      ((!std::isinf(state_bg[2])) && (!std::isnan(state_bg[2]))) &&
      ((!std::isinf(state_ba[0])) && (!std::isnan(state_ba[0]))) &&
      ((!std::isinf(state_ba[1])) && (!std::isnan(state_ba[1]))) &&
      ((!std::isinf(state_ba[2])) && (!std::isnan(state_ba[2]))) &&
      ((!std::isinf(state_c[0])) && (!std::isnan(state_c[0]))) &&
      ((!std::isinf(state_c[1])) && (!std::isnan(state_c[1]))) &&
      ((!std::isinf(state_c[2])) && (!std::isnan(state_c[2])))) {
    ok = true;
    for (int i{0}; i < 18; i++) {
      for (int j{0}; j < 18; j++) {
        double d;
        d = state_P[i + 18 * j];
        ok = ((!std::isinf(d)) && (!std::isnan(d)) && ok);
      }
    }
    if (ok &&
        ((!std::isinf(state_last_ts[0])) && (!std::isnan(state_last_ts[0]))) &&
        ((!std::isinf(state_last_ts[1])) && (!std::isnan(state_last_ts[1]))) &&
        ((!std::isinf(state_last_ts[2])) && (!std::isnan(state_last_ts[2]))) &&
        ((!std::isinf(state_last_ts[3])) && (!std::isnan(state_last_ts[3]))) &&
        ((!std::isinf(state_last_ts[4])) && (!std::isnan(state_last_ts[4]))) &&
        ((!std::isinf(state_last_ts[5])) && (!std::isnan(state_last_ts[5]))) &&
        ((!std::isinf(state_last_ts[6])) && (!std::isnan(state_last_ts[6]))) &&
        ((!std::isinf(state_last_accept_t[0])) &&
         (!std::isnan(state_last_accept_t[0]))) &&
        ((!std::isinf(state_last_accept_t[1])) &&
         (!std::isnan(state_last_accept_t[1]))) &&
        ((!std::isinf(state_last_accept_t[2])) &&
         (!std::isnan(state_last_accept_t[2]))) &&
        ((!std::isinf(state_last_accept_t[3])) &&
         (!std::isnan(state_last_accept_t[3]))) &&
        ((!std::isinf(state_last_accept_t[4])) &&
         (!std::isnan(state_last_accept_t[4]))) &&
        ((!std::isinf(state_last_accept_t[5])) &&
         (!std::isnan(state_last_accept_t[5]))) &&
        ((!std::isinf(state_last_accept_t[6])) &&
         (!std::isnan(state_last_accept_t[6])))) {
      ok = true;
    } else {
      ok = false;
    }
  } else {
    ok = false;
  }
  return ok;
}

//
// Arguments    : const double path_pad[96]
//                double n_path
// Return Type  : bool
//
static bool path_is_valid(const double path_pad[96], double n_path)
{
  bool b;
  bool ok;
  ok = false;
  b = ((!std::isinf(n_path)) && (!std::isnan(n_path)));
  if (b && (!(n_path < 2.0)) && (!(n_path > 32.0)) &&
      (!(n_path != std::floor(n_path)))) {
    int i;
    i = 0;
    int exitg1;
    do {
      exitg1 = 0;
      if (i < 96) {
        if (std::isinf(path_pad[i]) || std::isnan(path_pad[i])) {
          exitg1 = 1;
        } else {
          i++;
        }
      } else {
        ok = true;
        exitg1 = 1;
      }
    } while (exitg1 == 0);
  }
  return ok;
}

//
// Arguments    : const double path_pad[96]
//                double path_mat[96]
// Return Type  : void
//
static void path_unpad(const double path_pad[96], double path_mat[96])
{
  int k;
  k = 0;
  for (int j{0}; j < 3; j++) {
    std::copy(&path_pad[k],
              &path_pad[static_cast<int>(static_cast<unsigned int>(k) + 32U)],
              &path_mat[j * 32]);
    k += 32;
  }
}

//
// Arguments    : const double p[3]
//                const double path[96]
//                const double s_nodes[32]
//                double n
//                double s_lo
//                double s_hi
//                double &d_best
// Return Type  : double
//
static double project_interval_fixed(const double p[3], const double path[96],
                                     const double s_nodes[32], double n,
                                     double s_lo, double s_hi, double &d_best)
{
  double i0;
  double i1;
  double s_best;
  int k;
  bool exitg1;
  bool found0;
  d_best = rtInf;
  s_best = s_lo;
  //  i0 = max(1, find(s_nodes <= s_lo, 1, 'last')) with isempty -> 1
  i0 = 1.0;
  found0 = false;
  k = static_cast<int>(n);
  for (int b_k{0}; b_k < k; b_k++) {
    if (s_nodes[b_k] <= s_lo) {
      i0 = static_cast<double>(b_k) + 1.0;
      found0 = true;
    }
  }
  if (!found0) {
    i0 = 1.0;
  }
  //  i1 = min(n-1, find(s_nodes >= s_hi, 1, 'first')) with isempty -> n-1
  i1 = n - 1.0;
  found0 = false;
  k = 0;
  exitg1 = false;
  while ((!exitg1) && (k <= static_cast<int>(n) - 1)) {
    if (s_nodes[k] >= s_hi) {
      i1 = static_cast<double>(k) + 1.0;
      found0 = true;
      exitg1 = true;
    } else {
      k++;
    }
  }
  i0 = std::fmin(i0, n - 1.0);
  if (!found0) {
    i1 = n - 1.0;
  } else {
    i1 = std::fmin(n - 1.0, i1);
  }
  k = static_cast<int>(std::fmax(i1, i0) + (1.0 - i0));
  for (int b_k{0}; b_k < k; b_k++) {
    double ab[3];
    double y[3];
    double b_d;
    double d;
    double d1;
    double d2;
    double i;
    i = i0 + static_cast<double>(b_k);
    d = path[static_cast<int>(i) - 1];
    b_d = path[static_cast<int>(i + 1.0) - 1] - d;
    ab[0] = b_d;
    y[0] = b_d * b_d;
    d1 = path[static_cast<int>(i) + 31];
    b_d = path[static_cast<int>(i + 1.0) + 31] - d1;
    ab[1] = b_d;
    y[1] = b_d * b_d;
    d2 = path[static_cast<int>(i) + 63];
    b_d = path[static_cast<int>(i + 1.0) + 63] - d2;
    ab[2] = b_d;
    i1 = (y[0] + y[1]) + b_d * b_d;
    if (!(i1 < 1.0E-12)) {
      double t;
      y[0] = p[0] - d;
      y[1] = p[1] - d1;
      y[2] = p[2] - d2;
      t = std::fmax(0.0, std::fmin(1.0, coder::dot(y, ab) / i1));
      ab[0] = p[0] - (d + t * ab[0]);
      ab[1] = p[1] - (d1 + t * ab[1]);
      ab[2] = p[2] - (d2 + t * b_d);
      d = coder::b_norm(ab);
      i1 = s_nodes[static_cast<int>(i) - 1];
      i1 += t * (s_nodes[static_cast<int>(i + 1.0) - 1] - i1);
      if ((!(i1 < s_lo - 1.0E-9)) && (!(i1 > s_hi + 1.0E-9)) && (d < d_best)) {
        d_best = d;
        s_best = i1;
      }
    }
  }
  return s_best;
}

//
// Arguments    : const double q[4]
//                double R[9]
// Return Type  : void
//
static void quat2rot_local(const double q[4], double R[9])
{
  double R_tmp;
  double b_R_tmp;
  double c_R_tmp;
  double d_R_tmp;
  double e_R_tmp;
  double f_R_tmp;
  double g_R_tmp;
  R_tmp = q[3] * q[3];
  b_R_tmp = q[2] * q[2];
  R[0] = 1.0 - 2.0 * (b_R_tmp + R_tmp);
  c_R_tmp = q[1] * q[2];
  d_R_tmp = q[0] * q[3];
  R[3] = 2.0 * (c_R_tmp - d_R_tmp);
  e_R_tmp = q[1] * q[3];
  f_R_tmp = q[0] * q[2];
  R[6] = 2.0 * (e_R_tmp + f_R_tmp);
  R[1] = 2.0 * (c_R_tmp + d_R_tmp);
  g_R_tmp = q[1] * q[1];
  R[4] = 1.0 - 2.0 * (g_R_tmp + R_tmp);
  c_R_tmp = q[2] * q[3];
  d_R_tmp = q[0] * q[1];
  R[7] = 2.0 * (c_R_tmp - d_R_tmp);
  R[2] = 2.0 * (e_R_tmp - f_R_tmp);
  R[5] = 2.0 * (c_R_tmp + d_R_tmp);
  R[8] = 1.0 - 2.0 * (g_R_tmp + b_R_tmp);
}

//
// Arguments    : const double v[3]
//                double q[4]
// Return Type  : void
//
static void quat_from_rotvec_local(const double v[3], double q[4])
{
  double n;
  n = std::sqrt((v[0] * v[0] + v[1] * v[1]) + v[2] * v[2]);
  if (n < 1.0E-12) {
    q[0] = 1.0;
    q[1] = 0.5 * v[0];
    q[2] = 0.5 * v[1];
    q[3] = 0.5 * v[2];
  } else {
    double q_tmp;
    q_tmp = n / 2.0;
    q[0] = std::cos(q_tmp);
    n = std::sin(q_tmp) / n;
    q[1] = n * v[0];
    q[2] = n * v[1];
    q[3] = n * v[2];
  }
  n = std::sqrt(((q[0] * q[0] + q[1] * q[1]) + q[2] * q[2]) + q[3] * q[3]);
  if (n > 1.0E-18) {
    q[0] /= n;
    q[1] /= n;
    q[2] /= n;
    q[3] /= n;
  } else {
    q[0] = 1.0;
    q[1] = 0.0;
    q[2] = 0.0;
    q[3] = 0.0;
  }
}

//
// Arguments    : const double a[4]
//                const double b[4]
//                double q[4]
// Return Type  : void
//
static void quat_mul_local(const double a[4], const double b[4], double q[4])
{
  q[0] = ((a[0] * b[0] - a[1] * b[1]) - a[2] * b[2]) - a[3] * b[3];
  q[1] = ((a[0] * b[1] + b[0] * a[1]) + a[2] * b[3]) - b[2] * a[3];
  q[2] = ((a[0] * b[2] - a[1] * b[3]) + b[0] * a[2]) + b[1] * a[3];
  q[3] = ((a[0] * b[3] + a[1] * b[2]) - b[1] * a[2]) + b[0] * a[3];
}

//
// Arguments    : double q[4]
// Return Type  : void
//
static void quat_norm_local(double q[4])
{
  double nq;
  nq = std::sqrt(((q[0] * q[0] + q[1] * q[1]) + q[2] * q[2]) + q[3] * q[3]);
  if (nq > 1.0E-18) {
    q[0] /= nq;
    q[1] /= nq;
    q[2] /= nq;
    q[3] /= nq;
  } else {
    q[0] = 1.0;
    q[1] = 0.0;
    q[2] = 0.0;
    q[3] = 0.0;
  }
  if (q[0] < 0.0) {
    q[0] = -q[0];
    q[1] = -q[1];
    q[2] = -q[2];
    q[3] = -q[3];
  }
}

//
// Arguments    : const double R[9]
//                double e[3]
// Return Type  : void
//
static void rot2euler_local(const double R[9], double e[3])
{
  double r31;
  r31 = R[2];
  if (R[2] > 1.0) {
    r31 = 1.0;
  }
  if (r31 < -1.0) {
    r31 = -1.0;
  }
  e[0] = coder::b_atan2(R[5], R[8]);
  e[1] = -std::asin(r31);
  e[2] = coder::b_atan2(R[1], R[0]);
}

//
// Arguments    : double u
// Return Type  : double
//
static double rt_roundd_snf(double u)
{
  double y;
  if (std::abs(u) < 4.503599627370496E+15) {
    if (u >= 0.5) {
      y = std::floor(u + 0.5);
    } else if (u > -0.5) {
      y = u * 0.0;
    } else {
      y = std::ceil(u - 0.5);
    }
  } else {
    y = u;
  }
  return y;
}

//
// RUDDER_FDIR_CODEGEN_STEP Explicit-state one-step B2 rudder FDIR (fixed ABI).
//  DEPLOY_CANDIDATE / NOT_IN_PRODUCTION — isolated runtime; not production
//  path. Accepted valid-sample B2 math, warmup, command gate, Np persistence,
//  latch. Fail-silent on nonfinite, invalid, or non-increasing seq.
//  rudder_isolated is always false (no actuator corroboration; anomaly evidence
//  only).
//
//  health_bits (uint32): 1 SAMPLE_INVALID, 2 NONFINITE, 4 SEQ_NONINCREASING,
//  8 CONFIG_INVALID, 16 NOT_INIT. Nonzero => fail-silent.
//
//  Constraints: no global/persistent/nargin/assert/error/strings/NaN sentinels.
//
//  TASK_ID: RUDDER_FDIR_RUNTIME_001
//
// Arguments    : double params_G_nom
//                double params_thr_B2
//                double params_eps_dr_rad
//                double params_u_floor
//                double params_t_warmup_s
//                double params_Np
//                bool params_config_valid
//                struct14_T &state
//                double in_t
//                double in_delta_r_cmd
//                double in_r
//                double in_u
//                bool in_sample_valid
//                unsigned int in_seq
// Return Type  : e_struct_T
//
static e_struct_T
rudder_fdir_codegen_step(double params_G_nom, double params_thr_B2,
                         double params_eps_dr_rad, double params_u_floor,
                         double params_t_warmup_s, double params_Np,
                         bool params_config_valid, struct14_T &state,
                         double in_t, double in_delta_r_cmd, double in_r,
                         double in_u, bool in_sample_valid, unsigned int in_seq)
{
  e_struct_T out;
  double residual;
  unsigned int hb;
  hb = 0U;
  if (!state.initialized) {
    hb = 16U;
  }
  if (!params_config_valid) {
    hb |= 8U;
  }
  if (!in_sample_valid) {
    hb |= 1U;
  }
  if (std::isinf(in_t) || std::isnan(in_t) ||
      (std::isinf(in_delta_r_cmd) || std::isnan(in_delta_r_cmd)) ||
      (std::isinf(in_r) || std::isnan(in_r)) ||
      (std::isinf(in_u) || std::isnan(in_u))) {
    hb |= 2U;
  }
  if (state.have_seq && (in_seq <= state.last_seq)) {
    hb |= 4U;
  }
  residual = 0.0;
  if (hb == 0U) {
    double u_eff;
    bool gated;
    bool warmed;
    warmed = (in_t > params_t_warmup_s);
    if (warmed && (std::abs(in_delta_r_cmd) > params_eps_dr_rad)) {
      gated = true;
    } else {
      gated = false;
    }
    u_eff = std::fmax(in_u, params_u_floor);
    if (std::abs(in_delta_r_cmd) > 2.2204460492503131E-16) {
      double g_hat;
      g_hat = in_r / (u_eff * u_eff * in_delta_r_cmd);
      residual = 1.0 - g_hat / params_G_nom;
      if (residual < 0.0) {
        residual = 0.0;
      }
      if (std::isinf(residual) || std::isnan(residual)) {
        residual = 0.0;
      }
    }
    if (gated && (residual > params_thr_B2)) {
      gated = true;
    } else {
      gated = false;
    }
    if (gated) {
      state.persist_count++;
    } else {
      state.persist_count = 0.0;
    }
    if ((!state.anomaly_latched) && (state.persist_count >= params_Np)) {
      state.anomaly_latched = true;
      state.alarm_time_s = in_t;
      state.alarm_time_valid = true;
    }
    state.last_seq = in_seq;
    state.have_seq = true;
  } else {
    state.persist_count = 0.0;
  }
  out.residual = residual;
  out.anomaly_latched = state.anomaly_latched;
  out.health_bits = hb;
  return out;
}

//
// Arguments    : const double path[96]
//                const double s_nodes[32]
//                double n
//                double s
//                bool is_closed
//                double p[3]
//                double t_hat[3]
// Return Type  : void
//
static void sample_path_fixed(const double path[96], const double s_nodes[32],
                              double n, double s, bool is_closed, double p[3],
                              double t_hat[3])
{
  double b_i;
  double d;
  double d1;
  double ds;
  double ds_tmp;
  int i;
  unsigned int y;
  bool found;
  if (is_closed) {
    s = coder::b_mod(s, s_nodes[static_cast<int>(n) - 1]);
  } else {
    s = std::fmax(0.0, std::fmin(s_nodes[static_cast<int>(n) - 1], s));
  }
  //  i = max(1, min(n-1, find(s_nodes <= s, 1, 'last'))); isempty -> 1
  y = 1U;
  found = false;
  i = static_cast<int>(n);
  for (int k{0}; k < i; k++) {
    if (s_nodes[k] <= s) {
      y = static_cast<unsigned int>(k) + 1U;
      found = true;
    }
  }
  if (!found) {
    y = 1U;
  }
  b_i = std::fmax(1.0, std::fmin(n - 1.0, static_cast<double>(y)));
  ds_tmp = s_nodes[static_cast<int>(b_i) - 1];
  ds = s_nodes[static_cast<int>(b_i + 1.0) - 1] - ds_tmp;
  if (ds < 1.0E-12) {
    s = 0.0;
  } else {
    s = (s - ds_tmp) / ds;
  }
  ds_tmp = path[static_cast<int>(b_i) - 1];
  ds = path[static_cast<int>(b_i + 1.0) - 1] - ds_tmp;
  t_hat[0] = ds;
  p[0] = ds_tmp + s * ds;
  d = path[static_cast<int>(b_i) + 31];
  ds = path[static_cast<int>(b_i + 1.0) + 31] - d;
  t_hat[1] = ds;
  p[1] = d + s * ds;
  d1 = path[static_cast<int>(b_i) + 63];
  ds = path[static_cast<int>(b_i + 1.0) + 63] - d1;
  t_hat[2] = ds;
  p[2] = d1 + s * ds;
  if (coder::b_norm(t_hat) < 1.0E-9) {
    if (b_i > 1.0) {
      t_hat[0] = ds_tmp - path[static_cast<int>(b_i - 1.0) - 1];
      t_hat[1] = d - path[static_cast<int>(b_i - 1.0) + 31];
      t_hat[2] = d1 - path[static_cast<int>(b_i - 1.0) + 63];
    } else {
      t_hat[0] = 1.0;
      t_hat[1] = 0.0;
      t_hat[2] = 0.0;
    }
  }
  s = coder::b_norm(t_hat);
  t_hat[0] /= s;
  t_hat[1] /= s;
  t_hat[2] /= s;
}

//
// Arguments    : const double v[3]
//                double S[9]
// Return Type  : void
//
static void skew_local(const double v[3], double S[9])
{
  std::memset(&S[0], 0, 9U * sizeof(double));
  S[3] = -v[2];
  S[6] = v[1];
  S[1] = v[2];
  S[7] = -v[0];
  S[2] = -v[1];
  S[5] = v[0];
}

//
// AUV_RUNTIME_CODEGEN_INIT Nested supervisor Params from approved component
// inits.
//  PRETARGET DEPLOY_CANDIDATE / LOGICAL COMMANDS ONLY / NOT_IN_PRODUCTION /
//  NOT_CERTIFIED Compose controller/guidance/navigation/availability/FDIR;
//  freeze scheduler/arming.
//
//  TASK_ID: SUPERVISOR_INIT_RESET_001
//
// Arguments    : const struct0_T *cfg
//                struct5_T *params
// Return Type  : void
//
void auv_runtime_codegen_init(const struct0_T *cfg, struct5_T *params)
{
  bool availability_config_valid;
  bool component_config_ok;
  bool controller_limits_ok;
  bool fdir_config_valid;
  bool guidance_limits_ok;
  bool safe_thrust_ok;
  bool timing_ok;
  // CONTROLLER_CODEGEN_INIT Build fixed Params from golden snapshot fields.
  //  DEPLOY_CANDIDATE / NOT_IN_PRODUCTION — isolated explicit-state prototype.
  //  Params are taken only from the golden snapshot (no isempty defaults).
  //  TASK_ID: CG2A_CONTROLLER_EXPLICIT_STATE_PROTOTYPE_001
  params->controller.Kp_psi = cfg->controller.Kp_psi;
  params->controller.Kd_psi = cfg->controller.Kd_psi;
  params->controller.Kp_x = cfg->controller.Kp_x;
  params->controller.Kp_roll = cfg->controller.Kp_roll;
  params->controller.Kp_angle = cfg->controller.Kp_angle;
  params->controller.Ki_angle = cfg->controller.Ki_angle;
  params->controller.Kp_rate = cfg->controller.Kp_rate;
  params->controller.Ki_rate = cfg->controller.Ki_rate;
  params->controller.Kaw_pitch = cfg->controller.Kaw_pitch;
  params->controller.Kd_rate = cfg->controller.Kd_rate;
  params->controller.Kd_damp = cfg->controller.Kd_damp;
  params->controller.delta_r_max = cfg->controller.delta_r_max;
  params->controller.delta_e_max = cfg->controller.delta_e_max;
  params->controller.thrust_max = cfg->controller.thrust_max;
  params->controller.thrust_min = cfg->controller.thrust_min;
  params->controller.thrust_trim = cfg->controller.thrust_trim;
  params->controller.trim_speed_table[0] = cfg->controller.trim_speed_table[0];
  params->controller.trim_elevator_table[0] =
      cfg->controller.trim_elevator_table[0];
  params->controller.trim_speed_table[1] = cfg->controller.trim_speed_table[1];
  params->controller.trim_elevator_table[1] =
      cfg->controller.trim_elevator_table[1];
  params->controller.trim_speed_table[2] = cfg->controller.trim_speed_table[2];
  params->controller.trim_elevator_table[2] =
      cfg->controller.trim_elevator_table[2];
  params->controller.trim_speed_table[3] = cfg->controller.trim_speed_table[3];
  params->controller.trim_elevator_table[3] =
      cfg->controller.trim_elevator_table[3];
  params->controller.elevator_sign = cfg->controller.elevator_sign;
  params->controller.dt_controller = cfg->controller.dt_controller;
  params->controller.tau_rate = cfg->controller.tau_rate;
  params->controller.Muw = cfg->controller.Muw;
  params->controller.Muuds = cfg->controller.Muuds;
  params->controller.lambda_muw_ff = cfg->controller.lambda_muw_ff;
  params->controller.muw_ff_u_min = cfg->controller.muw_ff_u_min;
  params->controller.muw_ff_u_lo = cfg->controller.muw_ff_u_lo;
  params->controller.muw_ff_u_hi = cfg->controller.muw_ff_u_hi;
  params->controller.muw_ff_clamp_deg = cfg->controller.muw_ff_clamp_deg;
  params->controller.delta_e_trim = cfg->controller.delta_e_trim;
  params->controller.k_gamma_climb = cfg->controller.k_gamma_climb;
  params->controller.de_climb_lim = cfg->controller.de_climb_lim;
  params->controller.slew_max_rad_s = cfg->controller.slew_max_rad_s;
  // GUIDANCE_CODEGEN_INIT Build fixed cfg from golden params_snapshot fields.
  //  DEPLOY_CANDIDATE / NOT_IN_PRODUCTION — isolated explicit-state prototype.
  //  Params are taken only from the golden snapshot (no isempty defaults).
  //  TASK_ID: CG2B_GUIDANCE_EXPLICIT_STATE_PROTOTYPE_001
  params->guidance = cfg->guidance;
  // AVAILABILITY_CODEGEN_INIT Frozen Gate 5C FSM constants plus 7-channel ICD.
  //  DEPLOY_CANDIDATE / HEALTH_STATUS_ONLY / NOT_IN_PRODUCTION / NOT_CERTIFIED
  //  Isolated explicit-state runtime. Dwell constants remain ASSUMED /
  //  NOT_CERTIFIED. tau_fresh[i] = max(4*period[i],
  //  stale_limit[i]+period[i], 1.0) TASK_ID: AVAILABILITY_RUNTIME_001
  params->availability.present[0] = cfg->availability.present[0];
  params->availability.present[1] = cfg->availability.present[1];
  params->availability.present[2] = cfg->availability.present[2];
  params->availability.present[3] = cfg->availability.present[3];
  params->availability.present[4] = cfg->availability.present[4];
  params->availability.present[5] = cfg->availability.present[5];
  params->availability.present[6] = cfg->availability.present[6];
  params->availability.period[0] = cfg->availability.period[0];
  params->availability.period[1] = cfg->availability.period[1];
  params->availability.period[2] = cfg->availability.period[2];
  params->availability.period[3] = cfg->availability.period[3];
  params->availability.period[4] = cfg->availability.period[4];
  params->availability.period[5] = cfg->availability.period[5];
  params->availability.period[6] = cfg->availability.period[6];
  params->availability.stale_limit[0] = cfg->availability.stale_limit[0];
  params->availability.stale_limit[1] = cfg->availability.stale_limit[1];
  params->availability.stale_limit[2] = cfg->availability.stale_limit[2];
  params->availability.stale_limit[3] = cfg->availability.stale_limit[3];
  params->availability.stale_limit[4] = cfg->availability.stale_limit[4];
  params->availability.stale_limit[5] = cfg->availability.stale_limit[5];
  params->availability.stale_limit[6] = cfg->availability.stale_limit[6];
  for (int i{0}; i < 7; i++) {
    double a;
    double b;
    b = params->availability.period[i];
    a = 4.0 * b;
    b += params->availability.stale_limit[i];
    if (b > a) {
      a = b;
    }
    if (a < 1.0) {
      a = 1.0;
    }
    params->availability.tau_fresh[i] = a;
  }
  if ((!std::isinf(cfg->availability.period[0])) &&
      (!std::isnan(cfg->availability.period[0])) &&
      (cfg->availability.period[0] > 0.0) &&
      ((!std::isinf(cfg->availability.stale_limit[0])) &&
       (!std::isnan(cfg->availability.stale_limit[0]))) &&
      (cfg->availability.stale_limit[0] >= 0.0) &&
      ((!std::isinf(params->availability.tau_fresh[0])) &&
       (!std::isnan(params->availability.tau_fresh[0]))) &&
      (params->availability.tau_fresh[0] > 0.0) &&
      ((!std::isinf(cfg->availability.period[1])) &&
       (!std::isnan(cfg->availability.period[1]))) &&
      (cfg->availability.period[1] > 0.0) &&
      ((!std::isinf(cfg->availability.stale_limit[1])) &&
       (!std::isnan(cfg->availability.stale_limit[1]))) &&
      (cfg->availability.stale_limit[1] >= 0.0) &&
      ((!std::isinf(params->availability.tau_fresh[1])) &&
       (!std::isnan(params->availability.tau_fresh[1]))) &&
      (params->availability.tau_fresh[1] > 0.0) &&
      ((!std::isinf(cfg->availability.period[2])) &&
       (!std::isnan(cfg->availability.period[2]))) &&
      (cfg->availability.period[2] > 0.0) &&
      ((!std::isinf(cfg->availability.stale_limit[2])) &&
       (!std::isnan(cfg->availability.stale_limit[2]))) &&
      (cfg->availability.stale_limit[2] >= 0.0) &&
      ((!std::isinf(params->availability.tau_fresh[2])) &&
       (!std::isnan(params->availability.tau_fresh[2]))) &&
      (params->availability.tau_fresh[2] > 0.0) &&
      ((!std::isinf(cfg->availability.period[3])) &&
       (!std::isnan(cfg->availability.period[3]))) &&
      (cfg->availability.period[3] > 0.0) &&
      ((!std::isinf(cfg->availability.stale_limit[3])) &&
       (!std::isnan(cfg->availability.stale_limit[3]))) &&
      (cfg->availability.stale_limit[3] >= 0.0) &&
      ((!std::isinf(params->availability.tau_fresh[3])) &&
       (!std::isnan(params->availability.tau_fresh[3]))) &&
      (params->availability.tau_fresh[3] > 0.0) &&
      ((!std::isinf(cfg->availability.period[4])) &&
       (!std::isnan(cfg->availability.period[4]))) &&
      (cfg->availability.period[4] > 0.0) &&
      ((!std::isinf(cfg->availability.stale_limit[4])) &&
       (!std::isnan(cfg->availability.stale_limit[4]))) &&
      (cfg->availability.stale_limit[4] >= 0.0) &&
      ((!std::isinf(params->availability.tau_fresh[4])) &&
       (!std::isnan(params->availability.tau_fresh[4]))) &&
      (params->availability.tau_fresh[4] > 0.0) &&
      ((!std::isinf(cfg->availability.period[5])) &&
       (!std::isnan(cfg->availability.period[5]))) &&
      (cfg->availability.period[5] > 0.0) &&
      ((!std::isinf(cfg->availability.stale_limit[5])) &&
       (!std::isnan(cfg->availability.stale_limit[5]))) &&
      (cfg->availability.stale_limit[5] >= 0.0) &&
      ((!std::isinf(params->availability.tau_fresh[5])) &&
       (!std::isnan(params->availability.tau_fresh[5]))) &&
      (params->availability.tau_fresh[5] > 0.0) &&
      ((!std::isinf(cfg->availability.period[6])) &&
       (!std::isnan(cfg->availability.period[6]))) &&
      (cfg->availability.period[6] > 0.0) &&
      ((!std::isinf(cfg->availability.stale_limit[6])) &&
       (!std::isnan(cfg->availability.stale_limit[6]))) &&
      (cfg->availability.stale_limit[6] >= 0.0) &&
      ((!std::isinf(params->availability.tau_fresh[6])) &&
       (!std::isnan(params->availability.tau_fresh[6]))) &&
      (params->availability.tau_fresh[6] > 0.0)) {
    availability_config_valid = true;
  } else {
    availability_config_valid = false;
  }
  // RUDDER_FDIR_CODEGEN_INIT Build fixed Params from frozen B2 monitor fields.
  //  DEPLOY_CANDIDATE / NOT_IN_PRODUCTION — isolated explicit-state runtime.
  //  No isolation claim: B2 is anomaly evidence only.
  //  TASK_ID: RUDDER_FDIR_RUNTIME_001
  if ((!std::isinf(cfg->fdir.G_nom)) && (!std::isnan(cfg->fdir.G_nom)) &&
      (cfg->fdir.G_nom > 0.0) &&
      ((!std::isinf(cfg->fdir.thr_B2)) && (!std::isnan(cfg->fdir.thr_B2))) &&
      (cfg->fdir.thr_B2 >= 0.0) &&
      ((!std::isinf(cfg->fdir.eps_dr_rad)) &&
       (!std::isnan(cfg->fdir.eps_dr_rad))) &&
      (cfg->fdir.eps_dr_rad >= 0.0) &&
      ((!std::isinf(cfg->fdir.u_floor)) && (!std::isnan(cfg->fdir.u_floor))) &&
      (cfg->fdir.u_floor >= 0.0) &&
      ((!std::isinf(cfg->fdir.t_warmup_s)) &&
       (!std::isnan(cfg->fdir.t_warmup_s))) &&
      (cfg->fdir.t_warmup_s >= 0.0) &&
      ((!std::isinf(cfg->fdir.Np)) && (!std::isnan(cfg->fdir.Np))) &&
      (cfg->fdir.Np >= 1.0) &&
      ((!std::isinf(cfg->fdir.persist_s)) &&
       (!std::isnan(cfg->fdir.persist_s))) &&
      (cfg->fdir.persist_s >= 0.0) &&
      ((!std::isinf(cfg->fdir.dt)) && (!std::isnan(cfg->fdir.dt))) &&
      (cfg->fdir.dt > 0.0)) {
    fdir_config_valid = true;
  } else {
    fdir_config_valid = false;
  }
  if ((!std::isinf(cfg->controller.dt_controller)) &&
      (!std::isnan(cfg->controller.dt_controller)) &&
      (cfg->controller.dt_controller > 0.0) &&
      ((!std::isinf(cfg->guidance.dt_guidance)) &&
       (!std::isnan(cfg->guidance.dt_guidance))) &&
      (cfg->guidance.dt_guidance > 0.0) &&
      ((!std::isinf(cfg->guidance.dt_controller)) &&
       (!std::isnan(cfg->guidance.dt_controller))) &&
      (cfg->guidance.dt_controller > 0.0) &&
      ((!std::isinf(cfg->fdir.dt)) && (!std::isnan(cfg->fdir.dt))) &&
      (cfg->fdir.dt > 0.0) &&
      (std::abs(cfg->controller.dt_controller - 0.025) <= 1.0E-12) &&
      (std::abs(cfg->fdir.dt - 0.025) <= 1.0E-12) &&
      (std::abs(cfg->controller.dt_controller - cfg->fdir.dt) <= 1.0E-12) &&
      (std::abs(cfg->guidance.dt_controller - cfg->controller.dt_controller) <=
       1.0E-12) &&
      (std::abs(cfg->guidance.dt_guidance -
                3.0 * cfg->controller.dt_controller) <= 1.0E-12) &&
      (std::abs(cfg->guidance.dt_guidance - 0.075) <= 1.0E-12)) {
    timing_ok = true;
  } else {
    timing_ok = false;
  }
  if ((!std::isinf(cfg->controller.delta_r_max)) &&
      (!std::isnan(cfg->controller.delta_r_max)) &&
      (cfg->controller.delta_r_max > 0.0) &&
      ((!std::isinf(cfg->controller.delta_e_max)) &&
       (!std::isnan(cfg->controller.delta_e_max))) &&
      (cfg->controller.delta_e_max > 0.0) &&
      ((!std::isinf(cfg->controller.thrust_max)) &&
       (!std::isnan(cfg->controller.thrust_max))) &&
      ((!std::isinf(cfg->controller.thrust_min)) &&
       (!std::isnan(cfg->controller.thrust_min))) &&
      ((!std::isinf(cfg->controller.slew_max_rad_s)) &&
       (!std::isnan(cfg->controller.slew_max_rad_s))) &&
      (cfg->controller.slew_max_rad_s > 0.0)) {
    controller_limits_ok = true;
  } else {
    controller_limits_ok = false;
  }
  if ((!std::isinf(cfg->guidance.pitch_ref_max)) &&
      (!std::isnan(cfg->guidance.pitch_ref_max)) &&
      (cfg->guidance.pitch_ref_max > 0.0) &&
      ((!std::isinf(cfg->guidance.pitch_ref_rate_max)) &&
       (!std::isnan(cfg->guidance.pitch_ref_rate_max))) &&
      (cfg->guidance.pitch_ref_rate_max > 0.0) &&
      ((!std::isinf(cfg->guidance.yaw_slew_max_rad_s)) &&
       (!std::isnan(cfg->guidance.yaw_slew_max_rad_s))) &&
      (cfg->guidance.yaw_slew_max_rad_s > 0.0) &&
      ((!std::isinf(cfg->guidance.r_ff_max_rad_s)) &&
       (!std::isnan(cfg->guidance.r_ff_max_rad_s))) &&
      (cfg->guidance.r_ff_max_rad_s > 0.0)) {
    guidance_limits_ok = true;
  } else {
    guidance_limits_ok = false;
  }
  if (availability_config_valid && fdir_config_valid) {
    component_config_ok = true;
  } else {
    component_config_ok = false;
  }
  if ((!std::isinf(cfg->safe_thrust)) && (!std::isnan(cfg->safe_thrust)) &&
      (cfg->controller.thrust_min <= cfg->controller.thrust_max) &&
      (cfg->safe_thrust >= cfg->controller.thrust_min) &&
      (cfg->safe_thrust <= cfg->controller.thrust_max)) {
    safe_thrust_ok = true;
  } else {
    safe_thrust_ok = false;
  }
  params->config_valid = false;
  if (timing_ok && controller_limits_ok && guidance_limits_ok &&
      component_config_ok && safe_thrust_ok) {
    params->config_valid = true;
  }
  params->navigation.g_ned = 9.81;
  params->navigation.sigma_p = 0.0;
  params->navigation.sigma_a = 0.002;
  params->navigation.sigma_g = 0.00035;
  params->navigation.sigma_bg = 1.0E-5;
  params->navigation.sigma_ba = 0.0001;
  params->navigation.sigma_c = 0.001;
  params->navigation.R_depth = 0.0004;
  params->navigation.R_heading = 7.6154354946677142E-5;
  params->navigation.lat_depth = 0.6;
  params->navigation.lat_heading = 0.3;
  params->navigation.lat_ins = 0.5;
  params->navigation.lat_dvl = 0.5;
  params->navigation.lat_usbl = 1.5;
  params->navigation.P0_p_abs = 10000.0;
  params->navigation.R_ins[0] = 0.0004;
  params->navigation.R_dvl[0] = 0.0001;
  params->navigation.R_usbl[0] = 2.25;
  params->navigation.P0_p[0] = 0.010000000000000002;
  params->navigation.P0_v[0] = 0.09;
  params->navigation.P0_th[0] = 0.0012184696791468343;
  params->navigation.P0_bg[0] = 0.0001;
  params->navigation.P0_ba[0] = 0.0025000000000000005;
  params->navigation.P0_c[0] = 0.25;
  params->navigation.R_ins[1] = 0.0004;
  params->navigation.R_dvl[1] = 0.0001;
  params->navigation.R_usbl[1] = 2.25;
  params->navigation.P0_p[1] = 0.010000000000000002;
  params->navigation.P0_v[1] = 0.09;
  params->navigation.P0_th[1] = 0.0012184696791468343;
  params->navigation.P0_bg[1] = 0.0001;
  params->navigation.P0_ba[1] = 0.0025000000000000005;
  params->navigation.P0_c[1] = 0.25;
  params->navigation.R_ins[2] = 0.0009;
  params->navigation.R_dvl[2] = 0.000225;
  params->navigation.R_usbl[2] = 0.64000000000000012;
  params->navigation.P0_p[2] = 0.25;
  params->navigation.P0_v[2] = 0.09;
  params->navigation.P0_th[2] = 0.0027415567780803771;
  params->navigation.P0_bg[2] = 0.0001;
  params->navigation.P0_ba[2] = 0.0025000000000000005;
  params->navigation.P0_c[2] = 0.25;
  params->navigation.q_min_frac = 0.2;
  params->navigation.q_floor = 0.2;
  params->navigation.nis_scale = 100.0;
  params->navigation.dt_prop_max = 0.05;
  params->navigation.dt_prop_sub = 0.01;
  params->navigation.n_sub_max = 5.0;
  params->navigation.tol_time = 1.0E-12;
  params->navigation.tol_pair = 1.0E-9;
  params->navigation.config_valid = true;
  params->availability.T_degrade = 0.5;
  params->availability.T_lost = 2.0;
  params->availability.T_reacq = 0.5;
  params->availability.T_clear = 1.0;
  params->availability.T_settle = 3.0;
  params->availability.tol_time = 1.0E-12;
  params->availability.k_fresh = 4.0;
  params->availability.tau_floor = 1.0;
  params->availability.config_valid = availability_config_valid;
  params->fdir.G_nom = cfg->fdir.G_nom;
  params->fdir.thr_B2 = cfg->fdir.thr_B2;
  params->fdir.eps_dr_rad = cfg->fdir.eps_dr_rad;
  params->fdir.u_floor = cfg->fdir.u_floor;
  params->fdir.t_warmup_s = cfg->fdir.t_warmup_s;
  params->fdir.Np = cfg->fdir.Np;
  params->fdir.persist_s = cfg->fdir.persist_s;
  params->fdir.dt = cfg->fdir.dt;
  params->fdir.config_valid = fdir_config_valid;
  params->safe_thrust = cfg->safe_thrust;
  params->guidance_divider = 3U;
  params->arm_min_healthy_ticks = 3U;
}

//
// Arguments    : void
// Return Type  : void
//
void auv_runtime_codegen_init_initialize()
{
}

//
// Arguments    : void
// Return Type  : void
//
void auv_runtime_codegen_init_terminate()
{
}

//
// AUV_RUNTIME_CODEGEN_RESET Deterministic finite supervisor/component State.
//  PRETARGET DEPLOY_CANDIDATE / LOGICAL COMMANDS ONLY / NOT_IN_PRODUCTION /
//  NOT_CERTIFIED Nested states from approved reset entry points. FAULT_LATCHED
//  clears here only.
//
//  TASK_ID: SUPERVISOR_INIT_RESET_001
//
// Arguments    : const struct5_T *params
//                struct9_T *state
// Return Type  : void
//
void auv_runtime_codegen_reset(const struct5_T *, struct9_T *state)
{
  state->controller.prev_delta_r = 0.0;
  state->controller.prev_delta_e = 0.0;
  state->controller.int_angle = 0.0;
  state->controller.int_rate = 0.0;
  state->controller.rate_filt = 0.0;
  state->controller.prev_e_rate = 0.0;
  state->controller.initialized = 1.0;
  state->guidance.initialized = false;
  state->guidance.s_prog = 0.0;
  state->guidance.yaw_cont = 0.0;
  state->guidance.pitch_f = 0.0;
  state->guidance.z_e_f = 0.0;
  state->guidance.z_e_i = 0.0;
  state->guidance.zd_e_f = 0.0;
  state->guidance.eg_f = 0.0;
  state->guidance.alpha_hat = 0.0;
  state->guidance.kappa_f = 0.0;
  state->guidance.chi_f = 0.0;
  state->guidance.yaw_out = 0.0;
  state->guidance.pitch_out = 0.0;
  state->guidance.have_yaw_cont = false;
  state->guidance.have_pitch_f = false;
  state->guidance.have_chi_f = false;
  state->guidance.have_yaw_out = false;
  state->navigation.initialized = false;
  state->navigation.p[0] = 0.0;
  state->navigation.v[0] = 0.0;
  state->navigation.p[1] = 0.0;
  state->navigation.v[1] = 0.0;
  state->navigation.p[2] = 0.0;
  state->navigation.v[2] = 0.0;
  state->navigation.q[0] = 1.0;
  state->navigation.q[1] = 0.0;
  state->navigation.q[2] = 0.0;
  state->navigation.q[3] = 0.0;
  state->navigation.bg[0] = 0.0;
  state->navigation.ba[0] = 0.0;
  state->navigation.c[0] = 0.0;
  state->navigation.bg[1] = 0.0;
  state->navigation.ba[1] = 0.0;
  state->navigation.c[1] = 0.0;
  state->navigation.bg[2] = 0.0;
  state->navigation.ba[2] = 0.0;
  state->navigation.c[2] = 0.0;
  std::memset(&state->navigation.P[0], 0, 324U * sizeof(double));
  state->navigation.est_seq = 0U;
  state->availability.code = 0U;
  state->availability.deg_timer = 0.0;
  state->availability.loss_timer = 0.0;
  state->availability.posok_timer = 0.0;
  state->availability.allok_timer = 0.0;
  for (int i{0}; i < 7; i++) {
    state->navigation.last_seq[i] = 0U;
    state->navigation.have_seq[i] = false;
    state->navigation.last_ts[i] = 0.0;
    state->navigation.have_ts[i] = false;
    state->navigation.last_accept_t[i] = 0.0;
    state->navigation.have_accept_t[i] = false;
    state->availability.last_accept_t[i] = 0.0;
    state->availability.have_accept[i] = false;
  }
  state->availability.init_time = 0.0;
  state->availability.last_t = 0.0;
  state->availability.have_init = false;
  state->availability.have_t = false;
  state->availability.trans_count = 0U;
  state->availability.trans_from = 0U;
  state->availability.trans_to = 0U;
  state->fdir.initialized = true;
  state->fdir.persist_count = 0.0;
  state->fdir.anomaly_latched = false;
  state->fdir.alarm_time_s = 0.0;
  state->fdir.alarm_time_valid = false;
  state->fdir.last_seq = 0U;
  state->fdir.have_seq = false;
  state->tick_count = 0U;
  state->have_tick = false;
  state->last_tick_seq = 0U;
  state->last_t = 0.0;
  state->progress_index = 1.0;
  state->yaw = 0.0;
  state->pitch = 0.0;
  state->u = 0.0;
  state->r_ff = 0.0;
  state->pitch_dot = 0.0;
  state->guidance_ready = false;
  state->arm_state = 0U;
  state->healthy_streak = 0U;
  state->fault_bits_latched = 0U;
}

//
// AUV_RUNTIME_CODEGEN_STEP Ordered supervisor step and logical safety
// interlock.
//  PRETARGET DEPLOY_CANDIDATE / LOGICAL COMMANDS ONLY / NOT_IN_PRODUCTION /
//  NOT_CERTIFIED Fixed-shape composition: validate, nav, availability, /3
//  guidance hold, controller, FDIR (status only), then arm/safe publish. No
//  physical authority.
//
//  TASK_ID: SUPERVISOR_NAV_READY_REPAIR_001
//
// Arguments    : const struct5_T *params
//                struct9_T *state
//                const struct15_T *in
//                struct17_T *out
// Return Type  : void
//
void auv_runtime_codegen_step(const struct5_T *params, struct9_T *state,
                              const struct15_T *in, struct17_T *out)
{
  c_struct_T expl_temp;
  d_struct_T b_expl_temp;
  e_struct_T d_expl_temp;
  struct_T c_expl_temp;
  double ctrl_de;
  double ctrl_th;
  double dt_nav;
  double pub_de;
  double pub_dr;
  double safe_thrust;
  unsigned int hb;
  unsigned int latch_src;
  unsigned int qY;
  bool guidance_due;
  bool input_ok;
  bool nav_t_finite;
  bool order_ok;
  bool path_ok;
  bool rates_ok;
  bool t_finite;
  bool t_inc;
  bool time_match;
  hb = 0U;
  t_finite = ((!std::isinf(in->t)) && (!std::isnan(in->t)));
  nav_t_finite = ((!std::isinf(in->nav.t)) && (!std::isnan(in->nav.t)));
  if (t_finite && nav_t_finite && in->sample_valid) {
    input_ok = true;
  } else {
    input_ok = false;
  }
  time_match = false;
  if (t_finite && nav_t_finite) {
    dt_nav = in->t - in->nav.t;
    if (dt_nav < 0.0) {
      dt_nav = -dt_nav;
    }
    time_match = (dt_nav <= 1.0E-12);
  }
  nav_t_finite = true;
  t_inc = t_finite;
  if (state->have_tick) {
    nav_t_finite = (in->tick_seq > state->last_tick_seq);
    t_inc = false;
    if (t_finite) {
      t_inc = (in->t > state->last_t);
    }
  }
  if (nav_t_finite && t_inc && time_match) {
    order_ok = true;
  } else {
    order_ok = false;
  }
  path_ok = path_is_valid(in->path_pad, in->n_path);
  if ((!std::isinf(in->body_rates[0])) && (!std::isnan(in->body_rates[0])) &&
      ((!std::isinf(in->body_rates[1])) && (!std::isnan(in->body_rates[1]))) &&
      ((!std::isinf(in->body_rates[2])) && (!std::isnan(in->body_rates[2])))) {
    rates_ok = true;
  } else {
    rates_ok = false;
  }
  if (!params->config_valid) {
    hb = 1U;
  }
  if (!input_ok) {
    hb |= 2U;
  }
  if (!nav_t_finite) {
    hb |= 4U;
  }
  if ((!t_inc) || (!time_match)) {
    hb |= 8U;
  }
  if (!path_ok) {
    hb |= 16U;
  }
  if (!rates_ok) {
    hb |= 32U;
  }
  guidance_due = false;
  if (order_ok) {
    if (params->guidance_divider == 0U) {
      latch_src = state->tick_count;
    } else {
      latch_src = state->tick_count - state->tick_count /
                                          params->guidance_divider *
                                          params->guidance_divider;
    }
    guidance_due = (latch_src == 0U);
    state->have_tick = true;
    state->last_tick_seq = in->tick_seq;
    state->last_t = in->t;
    latch_src = state->tick_count;
    qY = latch_src + 1U;
    if (latch_src + 1U < latch_src) {
      qY = MAX_uint32_T;
    }
    state->tick_count = qY;
  }
  //  ----- 2. one navigation operation -----
  nav_codegen_step(params->navigation, state->navigation, in->nav, expl_temp);
  out->nav_p[0] = expl_temp.p[0];
  out->nav_p[1] = expl_temp.p[1];
  out->nav_p[2] = expl_temp.p[2];
  out->nav_v[0] = expl_temp.v[0];
  out->nav_v[1] = expl_temp.v[1];
  out->nav_v[2] = expl_temp.v[2];
  out->nav_euler[0] = expl_temp.euler[0];
  out->nav_euler[1] = expl_temp.euler[1];
  out->nav_euler[2] = expl_temp.euler[2];
  out->nav_vel_body_water[0] = expl_temp.vel_body_water[0];
  out->nav_vel_body_water[1] = expl_temp.vel_body_water[1];
  out->nav_vel_body_water[2] = expl_temp.vel_body_water[2];
  out->nav_valid = expl_temp.valid;
  if (all_finite3(out->nav_p) && all_finite3(out->nav_v) &&
      all_finite3(out->nav_euler) && all_finite3(out->nav_vel_body_water)) {
    nav_t_finite = true;
  } else {
    nav_t_finite = false;
  }
  if (expl_temp.initialized && nav_t_finite) {
    nav_t_finite = true;
  } else {
    nav_t_finite = false;
  }
  if (((expl_temp.health_bits & 4U) != 0U) ||
      ((expl_temp.health_bits & 32768U) != 0U) ||
      ((expl_temp.health_bits & 65536U) != 0U)) {
    time_match = true;
  } else {
    time_match = false;
  }
  if (!expl_temp.initialized) {
    hb |= 64U;
  }
  if (time_match) {
    hb |= 128U;
  }
  //  ----- 3. availability every tick (status only) -----
  availability_codegen_step(
      params->availability.T_degrade, params->availability.T_lost,
      params->availability.T_reacq, params->availability.T_clear,
      params->availability.T_settle, params->availability.tol_time,
      params->availability.present, params->availability.tau_fresh,
      params->availability.config_valid, state->availability, in->t,
      expl_temp.initialized, in->accepted, b_expl_temp);
  out->availability_health_bits = b_expl_temp.health_bits;
  //  ----- 4. guidance on /3 ticks, else exact hold -----
  if ((!std::isinf(state->yaw)) && (!std::isnan(state->yaw)) &&
      ((!std::isinf(state->pitch)) && (!std::isnan(state->pitch))) &&
      ((!std::isinf(state->u)) && (!std::isnan(state->u))) &&
      ((!std::isinf(state->r_ff)) && (!std::isnan(state->r_ff))) &&
      ((!std::isinf(state->pitch_dot)) && (!std::isnan(state->pitch_dot))) &&
      ((!std::isinf(state->progress_index)) &&
       (!std::isnan(state->progress_index)))) {
    t_finite = true;
  } else {
    t_finite = false;
  }
  t_inc = !t_finite;
  if (t_inc) {
    hb |= 512U;
    state->yaw = 0.0;
    state->pitch = 0.0;
    state->u = 0.0;
    state->r_ff = 0.0;
    state->pitch_dot = 0.0;
    state->progress_index = 1.0;
    state->guidance_ready = false;
    t_finite = false;
  }
  if (guidance_due && nav_t_finite && path_ok && rates_ok &&
      params->config_valid && input_ok && (!t_inc) && (!time_match)) {
    double dv[96];
    path_unpad(in->path_pad, dv);
    pub_de = guidance_codegen_step(
        expl_temp.p, dv, in->n_path, state->progress_index,
        expl_temp.vel_body_water[0], expl_temp.vel_body_water[1],
        coder::b_hypot(expl_temp.v[0], expl_temp.v[1]), expl_temp.v[2],
        expl_temp.euler[1], params->guidance, state->guidance, dt_nav, ctrl_de,
        ctrl_th, safe_thrust, pub_dr);
    if ((!std::isinf(pub_de)) && (!std::isnan(pub_de)) &&
        ((!std::isinf(dt_nav)) && (!std::isnan(dt_nav))) &&
        ((!std::isinf(ctrl_de)) && (!std::isnan(ctrl_de))) &&
        ((!std::isinf(ctrl_th)) && (!std::isnan(ctrl_th))) &&
        ((!std::isinf(safe_thrust)) && (!std::isnan(safe_thrust))) &&
        ((!std::isinf(pub_dr)) && (!std::isnan(pub_dr)))) {
      state->yaw = pub_de;
      state->pitch = dt_nav;
      state->u = ctrl_de;
      state->r_ff = safe_thrust;
      state->pitch_dot = pub_dr;
      state->progress_index = ctrl_th;
      state->guidance_ready = true;
      t_finite = true;
    }
  }
  if (std::isinf(state->yaw) || std::isnan(state->yaw) ||
      (std::isinf(state->pitch) || std::isnan(state->pitch)) ||
      (std::isinf(state->u) || std::isnan(state->u)) ||
      (std::isinf(state->r_ff) || std::isnan(state->r_ff)) ||
      (std::isinf(state->pitch_dot) || std::isnan(state->pitch_dot)) ||
      (std::isinf(state->progress_index) ||
       std::isnan(state->progress_index))) {
    state->yaw = 0.0;
    state->pitch = 0.0;
    state->u = 0.0;
    state->r_ff = 0.0;
    state->pitch_dot = 0.0;
    state->progress_index = 1.0;
    state->guidance_ready = false;
    t_finite = false;
  }
  if (!state->guidance_ready) {
    hb |= 256U;
  }
  //  ----- 5. controller every tick when refs finite and nav initialized -----
  dt_nav = 0.0;
  ctrl_de = 0.0;
  ctrl_th = 0.0;
  if (t_finite && nav_t_finite && rates_ok && params->config_valid &&
      order_ok && input_ok && (!t_inc) && (!time_match)) {
    b_struct_T e_expl_temp;
    c_expl_temp.p = in->body_rates[0];
    c_expl_temp.w = expl_temp.vel_body_water[2];
    c_expl_temp.phi = expl_temp.euler[0];
    c_expl_temp.pitch_ref_dot = state->pitch_dot;
    c_expl_temp.r_ff = state->r_ff;
    c_expl_temp.u = expl_temp.vel_body_water[0];
    c_expl_temp.q = in->body_rates[1];
    c_expl_temp.r = in->body_rates[2];
    c_expl_temp.theta = expl_temp.euler[1];
    c_expl_temp.psi = expl_temp.euler[2];
    c_expl_temp.u_ref = state->u;
    c_expl_temp.pitch_ref = state->pitch;
    c_expl_temp.yaw_ref = state->yaw;
    e_expl_temp = controller_codegen_step(params->controller, state->controller,
                                          c_expl_temp);
    dt_nav = e_expl_temp.delta_r;
    ctrl_de = e_expl_temp.delta_e;
    ctrl_th = e_expl_temp.thrust;
    if ((!std::isinf(e_expl_temp.delta_r)) &&
        (!std::isnan(e_expl_temp.delta_r)) &&
        ((!std::isinf(e_expl_temp.delta_e)) &&
         (!std::isnan(e_expl_temp.delta_e))) &&
        ((!std::isinf(e_expl_temp.thrust)) &&
         (!std::isnan(e_expl_temp.thrust)))) {
      t_finite = true;
    } else {
      t_finite = false;
    }
    if (!t_finite) {
      dt_nav = 0.0;
      ctrl_de = 0.0;
      ctrl_th = 0.0;
    }
  }
  if (!t_finite) {
    hb |= 512U;
  }
  //  ----- 6. FDIR every tick from logical rudder command (status only) -----
  d_expl_temp = rudder_fdir_codegen_step(
      params->fdir.G_nom, params->fdir.thr_B2, params->fdir.eps_dr_rad,
      params->fdir.u_floor, params->fdir.t_warmup_s, params->fdir.Np,
      params->fdir.config_valid, state->fdir, in->t, dt_nav, in->body_rates[2],
      expl_temp.vel_body_water[0], in->sample_valid, in->tick_seq);
  out->fdir_residual = d_expl_temp.residual;
  if (std::isinf(d_expl_temp.residual) || std::isnan(d_expl_temp.residual)) {
    out->fdir_residual = 0.0;
  }
  out->fdir_health_bits = d_expl_temp.health_bits;
  if (in->kill_asserted) {
    hb |= 1024U;
  }
  if (d_expl_temp.anomaly_latched) {
    hb |= 2048U;
  }
  if (b_expl_temp.state == 3) {
    hb |= 4096U;
  }
  if (params->config_valid && input_ok && order_ok && path_ok && rates_ok &&
      nav_t_finite && state->guidance_ready && t_finite &&
      (!in->kill_asserted) && (!time_match)) {
    nav_t_finite = true;
  } else {
    nav_t_finite = false;
  }
  //  ----- 7. arm/safety interlock -----
  //  Status-only bits 2048/4096 never grant/remove authority or latch.
  latch_src = hb & 1791U;
  if (state->arm_state == 0) {
    latch_src = state->healthy_streak;
    qY = latch_src + 1U;
    if (latch_src + 1U < latch_src) {
      qY = MAX_uint32_T;
    }
    if (nav_t_finite) {
      state->healthy_streak = qY;
    } else {
      state->healthy_streak = 0U;
    }
    if (in->arm_request && (!in->disarm_request) &&
        (state->healthy_streak >= params->arm_min_healthy_ticks)) {
      state->arm_state = 1U;
    }
  } else if (state->arm_state == 1) {
    if ((latch_src != 0U) || in->kill_asserted || time_match) {
      state->arm_state = 2U;
      state->fault_bits_latched |= latch_src;
      state->fault_bits_latched |= 8192U;
      state->healthy_streak = 0U;
    } else if (in->disarm_request) {
      state->arm_state = 0U;
      state->healthy_streak = 0U;
    }
  } else {
    state->healthy_streak = 0U;
    state->fault_bits_latched |= latch_src;
    state->fault_bits_latched |= 8192U;
  }
  if (state->arm_state == 2) {
    hb |= 8192U;
  }
  safe_thrust = params->safe_thrust;
  if (std::isinf(params->safe_thrust) || std::isnan(params->safe_thrust)) {
    safe_thrust = 0.0;
  }
  if ((state->arm_state == 1) && nav_t_finite) {
    pub_dr = dt_nav;
    pub_de = ctrl_de;
    safe_thrust = ctrl_th;
    if ((!std::isinf(params->controller.delta_r_max)) &&
        (!std::isnan(params->controller.delta_r_max))) {
      if (dt_nav > params->controller.delta_r_max) {
        pub_dr = params->controller.delta_r_max;
      }
      if (pub_dr < -params->controller.delta_r_max) {
        pub_dr = -params->controller.delta_r_max;
      }
    }
    if ((!std::isinf(params->controller.delta_e_max)) &&
        (!std::isnan(params->controller.delta_e_max))) {
      if (ctrl_de > params->controller.delta_e_max) {
        pub_de = params->controller.delta_e_max;
      }
      if (pub_de < -params->controller.delta_e_max) {
        pub_de = -params->controller.delta_e_max;
      }
    }
    if ((!std::isinf(params->controller.thrust_max)) &&
        (!std::isnan(params->controller.thrust_max)) &&
        (ctrl_th > params->controller.thrust_max)) {
      safe_thrust = params->controller.thrust_max;
    }
    if ((!std::isinf(params->controller.thrust_min)) &&
        (!std::isnan(params->controller.thrust_min)) &&
        (safe_thrust < params->controller.thrust_min)) {
      safe_thrust = params->controller.thrust_min;
    }
    out->command_valid = true;
  } else {
    pub_dr = 0.0;
    pub_de = 0.0;
    out->command_valid = false;
  }
  out->delta_r = pub_dr;
  out->delta_e = pub_de;
  out->thrust = safe_thrust;
  out->arm_state = state->arm_state;
  out->ready = nav_t_finite;
  out->healthy_streak = state->healthy_streak;
  out->health_bits = hb;
  out->fault_bits_latched = state->fault_bits_latched;
  out->tick_count = state->tick_count;
  out->yaw = state->yaw;
  out->pitch = state->pitch;
  out->u = state->u;
  out->r_ff = state->r_ff;
  out->pitch_dot = state->pitch_dot;
  out->progress_index = state->progress_index;
  out->guidance_due = guidance_due;
  out->guidance_ready = state->guidance_ready;
  out->nav_initialized = expl_temp.initialized;
  out->nav_health_bits = expl_temp.health_bits;
  out->availability_state = b_expl_temp.state;
  out->fdir_anomaly_latched = d_expl_temp.anomaly_latched;
  out->ctrl_delta_r = dt_nav;
  out->ctrl_delta_e = ctrl_de;
  out->ctrl_thrust = ctrl_th;
  out->physical_io_written = false;
  out->actuator_isolated = false;
  out->abort_requested = false;
}

//
// File trailer for auv_runtime_codegen_init.cpp
//
// [EOF]
//
