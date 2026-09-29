//
// Academic License - for use in teaching, academic research, and meeting
// course requirements at degree granting institutions only.  Not for
// government, commercial, or other organizational use.
// File: main.cpp
//
// MATLAB Coder version            : 25.2
// C/C++ source code generated on  : 28-Aug-2026 17:25:48
//

/*************************************************************************/
/* This automatically generated example C++ main file shows how to call  */
/* entry-point functions that MATLAB Coder generated. You must customize */
/* this file for your application. Do not modify this file directly.     */
/* Instead, make a copy of this file, modify it, and integrate it into   */
/* your development environment.                                         */
/*                                                                       */
/* This file initializes entry-point function arguments to a default     */
/* size and value before calling the entry-point functions. It does      */
/* not store or use any values returned from the entry-point functions.  */
/* If necessary, it does pre-allocate memory for returned values.        */
/* You can use this file as a starting point for a main function that    */
/* you can deploy in your application.                                   */
/*                                                                       */
/* After you copy the file, and before you deploy it, you must make the  */
/* following changes:                                                    */
/* * For variable-size function arguments, change the example sizes to   */
/* the sizes that your application requires.                             */
/* * Change the example values of function arguments to the values that  */
/* your application requires.                                            */
/* * If the entry-point functions return values, store these values or   */
/* otherwise use them as required by your application.                   */
/*                                                                       */
/*************************************************************************/

// Include Files
#include "main.h"
#include "auv_runtime_codegen_init.h"
#include "auv_runtime_codegen_init_types.h"
#include "rt_nonfinite.h"

// Function Declarations
static void argInit_18x18_real_T(double result[324]);

static void argInit_1x4_real_T(double result[4]);

static void argInit_3x1_real_T(double result[3]);

static void argInit_5x1_real_T(double result[5]);

static void argInit_7x1_boolean_T(bool result[7]);

static void argInit_7x1_real_T(double result[7]);

static void argInit_7x1_uint32_T(unsigned int result[7]);

static void argInit_96x1_real_T(double result[96]);

static bool argInit_boolean_T();

static double argInit_real_T();

static void argInit_struct0_T(struct0_T &result);

static struct10_T argInit_struct10_T();

static void argInit_struct11_T(struct11_T &result);

static void argInit_struct12_T(struct12_T &result);

static void argInit_struct13_T(struct13_T &result);

static struct14_T argInit_struct14_T();

static void argInit_struct15_T(struct15_T &result);

static void argInit_struct16_T(struct16_T &result);

static void argInit_struct1_T(struct1_T &result);

static void argInit_struct2_T(struct2_T &result);

static void argInit_struct3_T(struct3_T &result);

static struct4_T argInit_struct4_T();

static void argInit_struct5_T(struct5_T &result);

static void argInit_struct6_T(struct6_T &result);

static void argInit_struct7_T(struct7_T &result);

static void argInit_struct8_T(struct8_T &result);

static void argInit_struct9_T(struct9_T &result);

static unsigned int argInit_uint32_T();

static unsigned char argInit_uint8_T();

// Function Definitions
//
// Arguments    : double result[324]
// Return Type  : void
//
static void argInit_18x18_real_T(double result[324])
{
  // Loop over the array to initialize each element.
  for (int i{0}; i < 324; i++) {
    // Set the value of the array element.
    // Change this value to the value that the application requires.
    result[i] = argInit_real_T();
  }
}

//
// Arguments    : double result[4]
// Return Type  : void
//
static void argInit_1x4_real_T(double result[4])
{
  // Loop over the array to initialize each element.
  for (int idx1{0}; idx1 < 4; idx1++) {
    // Set the value of the array element.
    // Change this value to the value that the application requires.
    result[idx1] = argInit_real_T();
  }
}

//
// Arguments    : double result[3]
// Return Type  : void
//
static void argInit_3x1_real_T(double result[3])
{
  // Loop over the array to initialize each element.
  for (int idx0{0}; idx0 < 3; idx0++) {
    // Set the value of the array element.
    // Change this value to the value that the application requires.
    result[idx0] = argInit_real_T();
  }
}

//
// Arguments    : double result[5]
// Return Type  : void
//
static void argInit_5x1_real_T(double result[5])
{
  // Loop over the array to initialize each element.
  for (int idx0{0}; idx0 < 5; idx0++) {
    // Set the value of the array element.
    // Change this value to the value that the application requires.
    result[idx0] = argInit_real_T();
  }
}

//
// Arguments    : bool result[7]
// Return Type  : void
//
static void argInit_7x1_boolean_T(bool result[7])
{
  // Loop over the array to initialize each element.
  for (int idx0{0}; idx0 < 7; idx0++) {
    // Set the value of the array element.
    // Change this value to the value that the application requires.
    result[idx0] = argInit_boolean_T();
  }
}

//
// Arguments    : double result[7]
// Return Type  : void
//
static void argInit_7x1_real_T(double result[7])
{
  // Loop over the array to initialize each element.
  for (int idx0{0}; idx0 < 7; idx0++) {
    // Set the value of the array element.
    // Change this value to the value that the application requires.
    result[idx0] = argInit_real_T();
  }
}

//
// Arguments    : unsigned int result[7]
// Return Type  : void
//
static void argInit_7x1_uint32_T(unsigned int result[7])
{
  // Loop over the array to initialize each element.
  for (int idx0{0}; idx0 < 7; idx0++) {
    // Set the value of the array element.
    // Change this value to the value that the application requires.
    result[idx0] = argInit_uint32_T();
  }
}

//
// Arguments    : double result[96]
// Return Type  : void
//
static void argInit_96x1_real_T(double result[96])
{
  // Loop over the array to initialize each element.
  for (int idx0{0}; idx0 < 96; idx0++) {
    // Set the value of the array element.
    // Change this value to the value that the application requires.
    result[idx0] = argInit_real_T();
  }
}

//
// Arguments    : void
// Return Type  : bool
//
static bool argInit_boolean_T()
{
  return false;
}

//
// Arguments    : void
// Return Type  : double
//
static double argInit_real_T()
{
  return 0.0;
}

//
// Arguments    : struct0_T &result
// Return Type  : void
//
static void argInit_struct0_T(struct0_T &result)
{
  // Set the value of each structure field.
  // Change this value to the value that the application requires.
  argInit_struct1_T(result.controller);
  argInit_struct2_T(result.guidance);
  argInit_struct3_T(result.availability);
  result.fdir = argInit_struct4_T();
  result.safe_thrust = argInit_real_T();
}

//
// Arguments    : void
// Return Type  : struct10_T
//
static struct10_T argInit_struct10_T()
{
  struct10_T result;
  double result_tmp;
  // Set the value of each structure field.
  // Change this value to the value that the application requires.
  result_tmp = argInit_real_T();
  result.prev_delta_r = result_tmp;
  result.prev_delta_e = result_tmp;
  result.int_angle = result_tmp;
  result.int_rate = result_tmp;
  result.rate_filt = result_tmp;
  result.prev_e_rate = result_tmp;
  result.initialized = result_tmp;
  return result;
}

//
// Arguments    : struct11_T &result
// Return Type  : void
//
static void argInit_struct11_T(struct11_T &result)
{
  double result_tmp;
  bool b_result_tmp;
  // Set the value of each structure field.
  // Change this value to the value that the application requires.
  result_tmp = argInit_real_T();
  b_result_tmp = argInit_boolean_T();
  result.initialized = b_result_tmp;
  result.s_prog = result_tmp;
  result.yaw_cont = result_tmp;
  result.pitch_f = result_tmp;
  result.z_e_f = result_tmp;
  result.z_e_i = result_tmp;
  result.zd_e_f = result_tmp;
  result.eg_f = result_tmp;
  result.alpha_hat = result_tmp;
  result.kappa_f = result_tmp;
  result.chi_f = result_tmp;
  result.yaw_out = result_tmp;
  result.pitch_out = result_tmp;
  result.have_yaw_cont = b_result_tmp;
  result.have_pitch_f = b_result_tmp;
  result.have_chi_f = b_result_tmp;
  result.have_yaw_out = b_result_tmp;
}

//
// Arguments    : struct12_T &result
// Return Type  : void
//
static void argInit_struct12_T(struct12_T &result)
{
  // Set the value of each structure field.
  // Change this value to the value that the application requires.
  argInit_3x1_real_T(result.p);
  argInit_7x1_boolean_T(result.have_seq);
  argInit_7x1_real_T(result.last_ts);
  result.initialized = argInit_boolean_T();
  argInit_1x4_real_T(result.q);
  argInit_18x18_real_T(result.P);
  argInit_7x1_uint32_T(result.last_seq);
  result.est_seq = argInit_uint32_T();
  result.v[0] = result.p[0];
  result.bg[0] = result.p[0];
  result.ba[0] = result.p[0];
  result.c[0] = result.p[0];
  result.v[1] = result.p[1];
  result.bg[1] = result.p[1];
  result.ba[1] = result.p[1];
  result.c[1] = result.p[1];
  result.v[2] = result.p[2];
  result.bg[2] = result.p[2];
  result.ba[2] = result.p[2];
  result.c[2] = result.p[2];
  for (int i{0}; i < 7; i++) {
    result.have_ts[i] = result.have_seq[i];
    result.last_accept_t[i] = result.last_ts[i];
    result.have_accept_t[i] = result.have_seq[i];
  }
}

//
// Arguments    : struct13_T &result
// Return Type  : void
//
static void argInit_struct13_T(struct13_T &result)
{
  double result_tmp;
  unsigned char c_result_tmp;
  bool b_result_tmp;
  // Set the value of each structure field.
  // Change this value to the value that the application requires.
  result_tmp = argInit_real_T();
  b_result_tmp = argInit_boolean_T();
  c_result_tmp = argInit_uint8_T();
  result.code = c_result_tmp;
  result.deg_timer = result_tmp;
  result.loss_timer = result_tmp;
  result.posok_timer = result_tmp;
  result.allok_timer = result_tmp;
  argInit_7x1_real_T(result.last_accept_t);
  argInit_7x1_boolean_T(result.have_accept);
  result.init_time = result_tmp;
  result.last_t = result_tmp;
  result.have_init = b_result_tmp;
  result.have_t = b_result_tmp;
  result.trans_count = argInit_uint32_T();
  result.trans_from = c_result_tmp;
  result.trans_to = c_result_tmp;
}

//
// Arguments    : void
// Return Type  : struct14_T
//
static struct14_T argInit_struct14_T()
{
  struct14_T result;
  double b_result_tmp;
  bool result_tmp;
  // Set the value of each structure field.
  // Change this value to the value that the application requires.
  result_tmp = argInit_boolean_T();
  b_result_tmp = argInit_real_T();
  result.initialized = result_tmp;
  result.persist_count = b_result_tmp;
  result.anomaly_latched = result_tmp;
  result.alarm_time_s = b_result_tmp;
  result.alarm_time_valid = result_tmp;
  result.last_seq = argInit_uint32_T();
  result.have_seq = result_tmp;
  return result;
}

//
// Arguments    : struct15_T &result
// Return Type  : void
//
static void argInit_struct15_T(struct15_T &result)
{
  double b_result_tmp;
  bool result_tmp;
  // Set the value of each structure field.
  // Change this value to the value that the application requires.
  result_tmp = argInit_boolean_T();
  b_result_tmp = argInit_real_T();
  result.t = b_result_tmp;
  result.tick_seq = argInit_uint32_T();
  result.sample_valid = result_tmp;
  result.arm_request = result_tmp;
  result.disarm_request = result_tmp;
  result.kill_asserted = result_tmp;
  argInit_struct16_T(result.nav);
  argInit_96x1_real_T(result.path_pad);
  result.n_path = b_result_tmp;
  argInit_3x1_real_T(result.body_rates);
  argInit_7x1_boolean_T(result.accepted);
}

//
// Arguments    : struct16_T &result
// Return Type  : void
//
static void argInit_struct16_T(struct16_T &result)
{
  double result_tmp;
  unsigned int c_result_tmp;
  unsigned char d_result_tmp;
  bool b_result_tmp;
  // Set the value of each structure field.
  // Change this value to the value that the application requires.
  argInit_3x1_real_T(result.init_gyro);
  result_tmp = argInit_real_T();
  argInit_5x1_real_T(result.init_timestamp);
  b_result_tmp = argInit_boolean_T();
  c_result_tmp = argInit_uint32_T();
  d_result_tmp = argInit_uint8_T();
  result.op = d_result_tmp;
  result.sample_valid = b_result_tmp;
  result.t = result_tmp;
  result.init_depth = result_tmp;
  result.init_heading = result_tmp;
  result.abs_position_present = b_result_tmp;
  result.gyro_timestamp = result_tmp;
  result.accel_timestamp = result_tmp;
  result.gyro_seq = c_result_tmp;
  result.accel_seq = c_result_tmp;
  result.channel = d_result_tmp;
  result.dim = d_result_tmp;
  result.present = b_result_tmp;
  result.packet_valid = b_result_tmp;
  result.status = d_result_tmp;
  result.timestamp = result_tmp;
  result.quality = result_tmp;
  result.stale_age = result_tmp;
  result.q_nom = result_tmp;
  result.stale_limit_s = result_tmp;
  result.seq = c_result_tmp;
  result.init_accel[0] = result.init_gyro[0];
  result.init_ins_vel[0] = result.init_gyro[0];
  result.init_accel[1] = result.init_gyro[1];
  result.init_ins_vel[1] = result.init_gyro[1];
  result.init_accel[2] = result.init_gyro[2];
  result.init_ins_vel[2] = result.init_gyro[2];
  for (int i{0}; i < 5; i++) {
    result.init_seq[i] = result.init_timestamp[i];
  }
  result.gyro[0] = result.init_gyro[0];
  result.accel[0] = result.init_gyro[0];
  result.value[0] = result.init_gyro[0];
  result.bound_lo[0] = result.init_gyro[0];
  result.bound_hi[0] = result.init_gyro[0];
  result.gyro[1] = result.init_gyro[1];
  result.accel[1] = result.init_gyro[1];
  result.value[1] = result.init_gyro[1];
  result.bound_lo[1] = result.init_gyro[1];
  result.bound_hi[1] = result.init_gyro[1];
  result.gyro[2] = result.init_gyro[2];
  result.accel[2] = result.init_gyro[2];
  result.value[2] = result.init_gyro[2];
  result.bound_lo[2] = result.init_gyro[2];
  result.bound_hi[2] = result.init_gyro[2];
}

//
// Arguments    : struct1_T &result
// Return Type  : void
//
static void argInit_struct1_T(struct1_T &result)
{
  double result_tmp;
  // Set the value of each structure field.
  // Change this value to the value that the application requires.
  result_tmp = argInit_real_T();
  argInit_1x4_real_T(result.trim_speed_table);
  result.Kp_psi = result_tmp;
  result.Kd_psi = result_tmp;
  result.Kp_x = result_tmp;
  result.Kp_roll = result_tmp;
  result.Kp_angle = result_tmp;
  result.Ki_angle = result_tmp;
  result.Kp_rate = result_tmp;
  result.Ki_rate = result_tmp;
  result.Kaw_pitch = result_tmp;
  result.Kd_rate = result_tmp;
  result.Kd_damp = result_tmp;
  result.delta_r_max = result_tmp;
  result.delta_e_max = result_tmp;
  result.thrust_max = result_tmp;
  result.thrust_min = result_tmp;
  result.thrust_trim = result_tmp;
  result.elevator_sign = result_tmp;
  result.dt_controller = result_tmp;
  result.tau_rate = result_tmp;
  result.Muw = result_tmp;
  result.Muuds = result_tmp;
  result.lambda_muw_ff = result_tmp;
  result.muw_ff_u_min = result_tmp;
  result.muw_ff_u_lo = result_tmp;
  result.muw_ff_u_hi = result_tmp;
  result.muw_ff_clamp_deg = result_tmp;
  result.delta_e_trim = result_tmp;
  result.k_gamma_climb = result_tmp;
  result.de_climb_lim = result_tmp;
  result.slew_max_rad_s = result_tmp;
  result.trim_elevator_table[0] = result.trim_speed_table[0];
  result.trim_elevator_table[1] = result.trim_speed_table[1];
  result.trim_elevator_table[2] = result.trim_speed_table[2];
  result.trim_elevator_table[3] = result.trim_speed_table[3];
}

//
// Arguments    : struct2_T &result
// Return Type  : void
//
static void argInit_struct2_T(struct2_T &result)
{
  double result_tmp;
  // Set the value of each structure field.
  // Change this value to the value that the application requires.
  result_tmp = argInit_real_T();
  result.MAX_PATH_POINTS = result_tmp;
  result.lookahead_distance = result_tmp;
  result.desired_speed = result_tmp;
  result.pitch_ref_max = result_tmp;
  result.pitch_ref_rate_max = result_tmp;
  result.dt_guidance = result_tmp;
  result.dt_controller = result_tmp;
  result.K_zdot = result_tmp;
  result.K_gamma = result_tmp;
  result.enable_alpha_hat = argInit_boolean_T();
  result.k_beta = result_tmp;
  result.closed_eps = result_tmp;
  result.near_end_margin = result_tmp;
  result.mono_back_max = result_tmp;
  result.s_back_tol = result_tmp;
  result.yaw_slew_max_rad_s = result_tmp;
  result.r_ff_max_rad_s = result_tmp;
  result.pitch_corr_max = result_tmp;
  result.z_e_i_max = result_tmp;
  result.alpha_hat_max = result_tmp;
}

//
// Arguments    : struct3_T &result
// Return Type  : void
//
static void argInit_struct3_T(struct3_T &result)
{
  // Set the value of each structure field.
  // Change this value to the value that the application requires.
  argInit_7x1_real_T(result.period);
  argInit_7x1_boolean_T(result.present);
  for (int i{0}; i < 7; i++) {
    result.stale_limit[i] = result.period[i];
  }
}

//
// Arguments    : void
// Return Type  : struct4_T
//
static struct4_T argInit_struct4_T()
{
  struct4_T result;
  double result_tmp;
  // Set the value of each structure field.
  // Change this value to the value that the application requires.
  result_tmp = argInit_real_T();
  result.G_nom = result_tmp;
  result.thr_B2 = result_tmp;
  result.eps_dr_rad = result_tmp;
  result.u_floor = result_tmp;
  result.t_warmup_s = result_tmp;
  result.Np = result_tmp;
  result.persist_s = result_tmp;
  result.dt = result_tmp;
  return result;
}

//
// Arguments    : struct5_T &result
// Return Type  : void
//
static void argInit_struct5_T(struct5_T &result)
{
  unsigned int result_tmp;
  // Set the value of each structure field.
  // Change this value to the value that the application requires.
  result_tmp = argInit_uint32_T();
  argInit_struct1_T(result.controller);
  argInit_struct2_T(result.guidance);
  argInit_struct6_T(result.navigation);
  argInit_struct7_T(result.availability);
  argInit_struct8_T(result.fdir);
  result.safe_thrust = argInit_real_T();
  result.guidance_divider = result_tmp;
  result.arm_min_healthy_ticks = result_tmp;
  result.config_valid = argInit_boolean_T();
}

//
// Arguments    : struct6_T &result
// Return Type  : void
//
static void argInit_struct6_T(struct6_T &result)
{
  double result_tmp;
  // Set the value of each structure field.
  // Change this value to the value that the application requires.
  result_tmp = argInit_real_T();
  argInit_3x1_real_T(result.R_ins);
  result.g_ned = result_tmp;
  result.sigma_p = result_tmp;
  result.sigma_a = result_tmp;
  result.sigma_g = result_tmp;
  result.sigma_bg = result_tmp;
  result.sigma_ba = result_tmp;
  result.sigma_c = result_tmp;
  result.R_depth = result_tmp;
  result.R_heading = result_tmp;
  result.lat_depth = result_tmp;
  result.lat_heading = result_tmp;
  result.lat_ins = result_tmp;
  result.lat_dvl = result_tmp;
  result.lat_usbl = result_tmp;
  result.P0_p_abs = result_tmp;
  result.q_min_frac = result_tmp;
  result.q_floor = result_tmp;
  result.nis_scale = result_tmp;
  result.dt_prop_max = result_tmp;
  result.dt_prop_sub = result_tmp;
  result.n_sub_max = result_tmp;
  result.tol_time = result_tmp;
  result.tol_pair = result_tmp;
  result.config_valid = argInit_boolean_T();
  result.R_dvl[0] = result.R_ins[0];
  result.R_usbl[0] = result.R_ins[0];
  result.P0_p[0] = result.R_ins[0];
  result.P0_v[0] = result.R_ins[0];
  result.P0_th[0] = result.R_ins[0];
  result.P0_bg[0] = result.R_ins[0];
  result.P0_ba[0] = result.R_ins[0];
  result.P0_c[0] = result.R_ins[0];
  result.R_dvl[1] = result.R_ins[1];
  result.R_usbl[1] = result.R_ins[1];
  result.P0_p[1] = result.R_ins[1];
  result.P0_v[1] = result.R_ins[1];
  result.P0_th[1] = result.R_ins[1];
  result.P0_bg[1] = result.R_ins[1];
  result.P0_ba[1] = result.R_ins[1];
  result.P0_c[1] = result.R_ins[1];
  result.R_dvl[2] = result.R_ins[2];
  result.R_usbl[2] = result.R_ins[2];
  result.P0_p[2] = result.R_ins[2];
  result.P0_v[2] = result.R_ins[2];
  result.P0_th[2] = result.R_ins[2];
  result.P0_bg[2] = result.R_ins[2];
  result.P0_ba[2] = result.R_ins[2];
  result.P0_c[2] = result.R_ins[2];
}

//
// Arguments    : struct7_T &result
// Return Type  : void
//
static void argInit_struct7_T(struct7_T &result)
{
  double result_tmp;
  // Set the value of each structure field.
  // Change this value to the value that the application requires.
  result_tmp = argInit_real_T();
  argInit_7x1_real_T(result.period);
  result.T_degrade = result_tmp;
  result.T_lost = result_tmp;
  result.T_reacq = result_tmp;
  result.T_clear = result_tmp;
  result.T_settle = result_tmp;
  result.tol_time = result_tmp;
  result.k_fresh = result_tmp;
  result.tau_floor = result_tmp;
  argInit_7x1_boolean_T(result.present);
  result.config_valid = argInit_boolean_T();
  for (int i{0}; i < 7; i++) {
    result.stale_limit[i] = result.period[i];
    result.tau_fresh[i] = result.period[i];
  }
}

//
// Arguments    : struct8_T &result
// Return Type  : void
//
static void argInit_struct8_T(struct8_T &result)
{
  double result_tmp;
  // Set the value of each structure field.
  // Change this value to the value that the application requires.
  result_tmp = argInit_real_T();
  result.G_nom = result_tmp;
  result.thr_B2 = result_tmp;
  result.eps_dr_rad = result_tmp;
  result.u_floor = result_tmp;
  result.t_warmup_s = result_tmp;
  result.Np = result_tmp;
  result.persist_s = result_tmp;
  result.dt = result_tmp;
  result.config_valid = argInit_boolean_T();
}

//
// Arguments    : struct9_T &result
// Return Type  : void
//
static void argInit_struct9_T(struct9_T &result)
{
  double b_result_tmp;
  unsigned int result_tmp;
  bool c_result_tmp;
  // Set the value of each structure field.
  // Change this value to the value that the application requires.
  result_tmp = argInit_uint32_T();
  b_result_tmp = argInit_real_T();
  c_result_tmp = argInit_boolean_T();
  result.controller = argInit_struct10_T();
  argInit_struct11_T(result.guidance);
  argInit_struct12_T(result.navigation);
  argInit_struct13_T(result.availability);
  result.fdir = argInit_struct14_T();
  result.tick_count = result_tmp;
  result.have_tick = c_result_tmp;
  result.last_tick_seq = result_tmp;
  result.last_t = b_result_tmp;
  result.progress_index = b_result_tmp;
  result.yaw = b_result_tmp;
  result.pitch = b_result_tmp;
  result.u = b_result_tmp;
  result.r_ff = b_result_tmp;
  result.pitch_dot = b_result_tmp;
  result.guidance_ready = c_result_tmp;
  result.arm_state = argInit_uint8_T();
  result.healthy_streak = result_tmp;
  result.fault_bits_latched = result_tmp;
}

//
// Arguments    : void
// Return Type  : unsigned int
//
static unsigned int argInit_uint32_T()
{
  return 0U;
}

//
// Arguments    : void
// Return Type  : unsigned char
//
static unsigned char argInit_uint8_T()
{
  return 0U;
}

//
// Arguments    : int argc
//                char **argv
// Return Type  : int
//
int main(int, char **)
{
  // Initialize the application.
  // You do not need to do this more than one time.
  auv_runtime_codegen_init_initialize();
  // Invoke the entry-point functions.
  // You can call entry-point functions multiple times.
  main_auv_runtime_codegen_init();
  main_auv_runtime_codegen_reset();
  main_auv_runtime_codegen_step();
  // Terminate the application.
  // You do not need to do this more than one time.
  auv_runtime_codegen_init_terminate();
  return 0;
}

//
// Arguments    : void
// Return Type  : void
//
void main_auv_runtime_codegen_init()
{
  struct0_T r;
  struct5_T params;
  // Initialize function 'auv_runtime_codegen_init' input arguments.
  // Initialize function input argument 'cfg'.
  // Call the entry-point 'auv_runtime_codegen_init'.
  argInit_struct0_T(r);
  auv_runtime_codegen_init(&r, &params);
}

//
// Arguments    : void
// Return Type  : void
//
void main_auv_runtime_codegen_reset()
{
  struct5_T r;
  struct9_T state;
  // Initialize function 'auv_runtime_codegen_reset' input arguments.
  // Initialize function input argument 'params'.
  // Call the entry-point 'auv_runtime_codegen_reset'.
  argInit_struct5_T(r);
  auv_runtime_codegen_reset(&r, &state);
}

//
// Arguments    : void
// Return Type  : void
//
void main_auv_runtime_codegen_step()
{
  struct15_T r1;
  struct17_T out;
  struct5_T r;
  struct9_T state;
  // Initialize function 'auv_runtime_codegen_step' input arguments.
  // Initialize function input argument 'params'.
  // Initialize function input argument 'state'.
  // Initialize function input argument 'in'.
  // Call the entry-point 'auv_runtime_codegen_step'.
  argInit_struct9_T(state);
  argInit_struct5_T(r);
  argInit_struct15_T(r1);
  auv_runtime_codegen_step(&r, &state, &r1, &out);
}

//
// File trailer for main.cpp
//
// [EOF]
//
