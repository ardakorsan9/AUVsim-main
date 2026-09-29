//
// Academic License - for use in teaching, academic research, and meeting
// course requirements at degree granting institutions only.  Not for
// government, commercial, or other organizational use.
// File: _coder_auv_runtime_codegen_init_api.cpp
//
// MATLAB Coder version            : 25.2
// C/C++ source code generated on  : 28-Aug-2026 17:25:48
//

// Include Files
#include "_coder_auv_runtime_codegen_init_api.h"
#include "_coder_auv_runtime_codegen_init_mex.h"

// Variable Definitions
emlrtCTX emlrtRootTLSGlobal{nullptr};

emlrtContext emlrtContextGlobal{
    true,                                                 // bFirstTime
    false,                                                // bInitialized
    131675U,                                              // fVersionInfo
    nullptr,                                              // fErrorFunction
    "auv_runtime_codegen_init",                           // fFunctionName
    nullptr,                                              // fRTCallStack
    false,                                                // bDebugMode
    {2045744189U, 2170104910U, 2743257031U, 4284093946U}, // fSigWrd
    nullptr                                               // fSigMem
};

// Function Declarations
static void b_emlrt_marshallIn(const emlrtStack &sp, const mxArray *src,
                               const emlrtMsgIdentifier *msgId,
                               uint32_T ret[7]);

static boolean_T b_emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                                    const emlrtMsgIdentifier *parentId);

static void b_emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId, real_T y[7]);

static void c_emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId,
                               boolean_T y[7]);

static struct4_T d_emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                                    const emlrtMsgIdentifier *parentId);

static void d_emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId, real_T y[3]);

static void e_emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId, real_T y[4]);

static uint32_T e_emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                                   const emlrtMsgIdentifier *parentId);

static void emlrtExitTimeCleanupDtorFcn(const void *r);

static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *b_nullptr,
                             const char_T *identifier, struct0_T &y);

static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, struct0_T &y);

static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, struct3_T &y);

static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, struct1_T &y);

static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *b_nullptr,
                             const char_T *identifier, struct5_T &y);

static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, struct5_T &y);

static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *b_nullptr,
                             const char_T *identifier, struct9_T &y);

static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, struct9_T &y);

static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, uint32_T y[7]);

static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, struct11_T &y);

static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, struct12_T &y);

static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, struct8_T &y);

static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, struct13_T &y);

static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, struct6_T &y);

static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *b_nullptr,
                             const char_T *identifier, struct15_T &y);

static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, struct15_T &y);

static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, struct16_T &y);

static real_T emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId);

static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, struct2_T &y);

static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, real_T y[4]);

static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, struct7_T &y);

static const mxArray *emlrt_marshallOut(const struct1_T &u);

static const mxArray *emlrt_marshallOut(const real_T u[4]);

static const mxArray *emlrt_marshallOut(const struct6_T &u);

static const mxArray *emlrt_marshallOut(const struct9_T &u);

static const mxArray *emlrt_marshallOut(const struct12_T &u);

static const mxArray *emlrt_marshallOut(const struct13_T &u);

static const mxArray *emlrt_marshallOut(const struct17_T &u);

static const mxArray *emlrt_marshallOut(const struct5_T &u);

static void f_emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId,
                               real_T y[324]);

static struct10_T f_emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                                     const emlrtMsgIdentifier *parentId);

static void g_emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId, real_T y[5]);

static uint8_T g_emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                                  const emlrtMsgIdentifier *parentId);

static struct14_T h_emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                                     const emlrtMsgIdentifier *parentId);

static void h_emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId,
                               real_T y[96]);

static real_T i_emlrt_marshallIn(const emlrtStack &sp, const mxArray *src,
                                 const emlrtMsgIdentifier *msgId);

static void i_emlrt_marshallIn(const emlrtStack &sp, const mxArray *src,
                               const emlrtMsgIdentifier *msgId, real_T ret[4]);

static void j_emlrt_marshallIn(const emlrtStack &sp, const mxArray *src,
                               const emlrtMsgIdentifier *msgId, real_T ret[7]);

static boolean_T j_emlrt_marshallIn(const emlrtStack &sp, const mxArray *src,
                                    const emlrtMsgIdentifier *msgId);

static void k_emlrt_marshallIn(const emlrtStack &sp, const mxArray *src,
                               const emlrtMsgIdentifier *msgId,
                               boolean_T ret[7]);

static void l_emlrt_marshallIn(const emlrtStack &sp, const mxArray *src,
                               const emlrtMsgIdentifier *msgId, real_T ret[3]);

static uint32_T l_emlrt_marshallIn(const emlrtStack &sp, const mxArray *src,
                                   const emlrtMsgIdentifier *msgId);

static uint8_T m_emlrt_marshallIn(const emlrtStack &sp, const mxArray *src,
                                  const emlrtMsgIdentifier *msgId);

static void m_emlrt_marshallIn(const emlrtStack &sp, const mxArray *src,
                               const emlrtMsgIdentifier *msgId, real_T ret[4]);

static void n_emlrt_marshallIn(const emlrtStack &sp, const mxArray *src,
                               const emlrtMsgIdentifier *msgId,
                               real_T ret[324]);

static void o_emlrt_marshallIn(const emlrtStack &sp, const mxArray *src,
                               const emlrtMsgIdentifier *msgId, real_T ret[5]);

static void p_emlrt_marshallIn(const emlrtStack &sp, const mxArray *src,
                               const emlrtMsgIdentifier *msgId, real_T ret[96]);

// Function Definitions
//
// Arguments    : const emlrtStack &sp
//                const mxArray *u
//                const emlrtMsgIdentifier *parentId
//                real_T y[7]
// Return Type  : void
//
static void b_emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId, real_T y[7])
{
  j_emlrt_marshallIn(sp, emlrtAlias(u), parentId, y);
  emlrtDestroyArray(&u);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *src
//                const emlrtMsgIdentifier *msgId
//                uint32_T ret[7]
// Return Type  : void
//
static void b_emlrt_marshallIn(const emlrtStack &sp, const mxArray *src,
                               const emlrtMsgIdentifier *msgId, uint32_T ret[7])
{
  static const int32_T dims{7};
  uint32_T(*r)[7];
  emlrtCheckBuiltInR2012b((emlrtConstCTX)&sp, msgId, src, "uint32", false, 1U,
                          (const void *)&dims);
  r = (uint32_T(*)[7])emlrtMxGetData(src);
  for (int32_T i{0}; i < 7; i++) {
    ret[i] = (*r)[i];
  }
  emlrtDestroyArray(&src);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *u
//                const emlrtMsgIdentifier *parentId
// Return Type  : boolean_T
//
static boolean_T b_emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                                    const emlrtMsgIdentifier *parentId)
{
  boolean_T y;
  y = j_emlrt_marshallIn(sp, emlrtAlias(u), parentId);
  emlrtDestroyArray(&u);
  return y;
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *u
//                const emlrtMsgIdentifier *parentId
//                boolean_T y[7]
// Return Type  : void
//
static void c_emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId,
                               boolean_T y[7])
{
  k_emlrt_marshallIn(sp, emlrtAlias(u), parentId, y);
  emlrtDestroyArray(&u);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *u
//                const emlrtMsgIdentifier *parentId
// Return Type  : struct4_T
//
static struct4_T d_emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                                    const emlrtMsgIdentifier *parentId)
{
  static const int32_T dims{0};
  static const char_T *fieldNames[8]{"G_nom",     "thr_B2",     "eps_dr_rad",
                                     "u_floor",   "t_warmup_s", "Np",
                                     "persist_s", "dt"};
  emlrtMsgIdentifier thisId;
  struct4_T y;
  thisId.fParent = parentId;
  thisId.bParentIsCell = false;
  emlrtCheckStructR2012b((emlrtConstCTX)&sp, parentId, u, 8,
                         (const char_T **)&fieldNames[0], 0U,
                         (const void *)&dims);
  thisId.fIdentifier = "G_nom";
  y.G_nom = emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 0, "G_nom")),
      &thisId);
  thisId.fIdentifier = "thr_B2";
  y.thr_B2 = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 1, "thr_B2")),
      &thisId);
  thisId.fIdentifier = "eps_dr_rad";
  y.eps_dr_rad =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      2, "eps_dr_rad")),
                       &thisId);
  thisId.fIdentifier = "u_floor";
  y.u_floor = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 3, "u_floor")),
      &thisId);
  thisId.fIdentifier = "t_warmup_s";
  y.t_warmup_s =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      4, "t_warmup_s")),
                       &thisId);
  thisId.fIdentifier = "Np";
  y.Np = emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 5, "Np")),
      &thisId);
  thisId.fIdentifier = "persist_s";
  y.persist_s = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 6, "persist_s")),
      &thisId);
  thisId.fIdentifier = "dt";
  y.dt = emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 7, "dt")),
      &thisId);
  emlrtDestroyArray(&u);
  return y;
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *u
//                const emlrtMsgIdentifier *parentId
//                real_T y[3]
// Return Type  : void
//
static void d_emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId, real_T y[3])
{
  l_emlrt_marshallIn(sp, emlrtAlias(u), parentId, y);
  emlrtDestroyArray(&u);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *u
//                const emlrtMsgIdentifier *parentId
//                real_T y[4]
// Return Type  : void
//
static void e_emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId, real_T y[4])
{
  m_emlrt_marshallIn(sp, emlrtAlias(u), parentId, y);
  emlrtDestroyArray(&u);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *u
//                const emlrtMsgIdentifier *parentId
// Return Type  : uint32_T
//
static uint32_T e_emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                                   const emlrtMsgIdentifier *parentId)
{
  uint32_T y;
  y = l_emlrt_marshallIn(sp, emlrtAlias(u), parentId);
  emlrtDestroyArray(&u);
  return y;
}

//
// Arguments    : const void *r
// Return Type  : void
//
static void emlrtExitTimeCleanupDtorFcn(const void *r)
{
  emlrtExitTimeCleanup(&emlrtContextGlobal);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *u
//                const emlrtMsgIdentifier *parentId
//                struct3_T &y
// Return Type  : void
//
static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, struct3_T &y)
{
  static const int32_T dims{0};
  static const char_T *fieldNames[3]{"present", "period", "stale_limit"};
  emlrtMsgIdentifier thisId;
  thisId.fParent = parentId;
  thisId.bParentIsCell = false;
  emlrtCheckStructR2012b((emlrtConstCTX)&sp, parentId, u, 3,
                         (const char_T **)&fieldNames[0], 0U,
                         (const void *)&dims);
  thisId.fIdentifier = "present";
  c_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 0, "present")),
      &thisId, y.present);
  thisId.fIdentifier = "period";
  b_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 1, "period")),
      &thisId, y.period);
  thisId.fIdentifier = "stale_limit";
  b_emlrt_marshallIn(sp,
                     emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 2,
                                                    "stale_limit")),
                     &thisId, y.stale_limit);
  emlrtDestroyArray(&u);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *u
//                const emlrtMsgIdentifier *parentId
//                struct6_T &y
// Return Type  : void
//
static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, struct6_T &y)
{
  static const int32_T dims{0};
  static const char_T *fieldNames[33]{
      "g_ned",    "sigma_p",   "sigma_a",     "sigma_g",     "sigma_bg",
      "sigma_ba", "sigma_c",   "R_depth",     "R_heading",   "R_ins",
      "R_dvl",    "R_usbl",    "lat_depth",   "lat_heading", "lat_ins",
      "lat_dvl",  "lat_usbl",  "P0_p",        "P0_p_abs",    "P0_v",
      "P0_th",    "P0_bg",     "P0_ba",       "P0_c",        "q_min_frac",
      "q_floor",  "nis_scale", "dt_prop_max", "dt_prop_sub", "n_sub_max",
      "tol_time", "tol_pair",  "config_valid"};
  emlrtMsgIdentifier thisId;
  thisId.fParent = parentId;
  thisId.bParentIsCell = false;
  emlrtCheckStructR2012b((emlrtConstCTX)&sp, parentId, u, 33,
                         (const char_T **)&fieldNames[0], 0U,
                         (const void *)&dims);
  thisId.fIdentifier = "g_ned";
  y.g_ned = emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 0, "g_ned")),
      &thisId);
  thisId.fIdentifier = "sigma_p";
  y.sigma_p = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 1, "sigma_p")),
      &thisId);
  thisId.fIdentifier = "sigma_a";
  y.sigma_a = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 2, "sigma_a")),
      &thisId);
  thisId.fIdentifier = "sigma_g";
  y.sigma_g = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 3, "sigma_g")),
      &thisId);
  thisId.fIdentifier = "sigma_bg";
  y.sigma_bg = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 4, "sigma_bg")),
      &thisId);
  thisId.fIdentifier = "sigma_ba";
  y.sigma_ba = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 5, "sigma_ba")),
      &thisId);
  thisId.fIdentifier = "sigma_c";
  y.sigma_c = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 6, "sigma_c")),
      &thisId);
  thisId.fIdentifier = "R_depth";
  y.R_depth = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 7, "R_depth")),
      &thisId);
  thisId.fIdentifier = "R_heading";
  y.R_heading = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 8, "R_heading")),
      &thisId);
  thisId.fIdentifier = "R_ins";
  d_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 9, "R_ins")),
      &thisId, y.R_ins);
  thisId.fIdentifier = "R_dvl";
  d_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 10, "R_dvl")),
      &thisId, y.R_dvl);
  thisId.fIdentifier = "R_usbl";
  d_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 11, "R_usbl")),
      &thisId, y.R_usbl);
  thisId.fIdentifier = "lat_depth";
  y.lat_depth =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      12, "lat_depth")),
                       &thisId);
  thisId.fIdentifier = "lat_heading";
  y.lat_heading =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      13, "lat_heading")),
                       &thisId);
  thisId.fIdentifier = "lat_ins";
  y.lat_ins = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 14, "lat_ins")),
      &thisId);
  thisId.fIdentifier = "lat_dvl";
  y.lat_dvl = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 15, "lat_dvl")),
      &thisId);
  thisId.fIdentifier = "lat_usbl";
  y.lat_usbl = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 16, "lat_usbl")),
      &thisId);
  thisId.fIdentifier = "P0_p";
  d_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 17, "P0_p")),
      &thisId, y.P0_p);
  thisId.fIdentifier = "P0_p_abs";
  y.P0_p_abs = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 18, "P0_p_abs")),
      &thisId);
  thisId.fIdentifier = "P0_v";
  d_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 19, "P0_v")),
      &thisId, y.P0_v);
  thisId.fIdentifier = "P0_th";
  d_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 20, "P0_th")),
      &thisId, y.P0_th);
  thisId.fIdentifier = "P0_bg";
  d_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 21, "P0_bg")),
      &thisId, y.P0_bg);
  thisId.fIdentifier = "P0_ba";
  d_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 22, "P0_ba")),
      &thisId, y.P0_ba);
  thisId.fIdentifier = "P0_c";
  d_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 23, "P0_c")),
      &thisId, y.P0_c);
  thisId.fIdentifier = "q_min_frac";
  y.q_min_frac =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      24, "q_min_frac")),
                       &thisId);
  thisId.fIdentifier = "q_floor";
  y.q_floor = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 25, "q_floor")),
      &thisId);
  thisId.fIdentifier = "nis_scale";
  y.nis_scale =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      26, "nis_scale")),
                       &thisId);
  thisId.fIdentifier = "dt_prop_max";
  y.dt_prop_max =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      27, "dt_prop_max")),
                       &thisId);
  thisId.fIdentifier = "dt_prop_sub";
  y.dt_prop_sub =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      28, "dt_prop_sub")),
                       &thisId);
  thisId.fIdentifier = "n_sub_max";
  y.n_sub_max =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      29, "n_sub_max")),
                       &thisId);
  thisId.fIdentifier = "tol_time";
  y.tol_time = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 30, "tol_time")),
      &thisId);
  thisId.fIdentifier = "tol_pair";
  y.tol_pair = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 31, "tol_pair")),
      &thisId);
  thisId.fIdentifier = "config_valid";
  y.config_valid =
      b_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u,
                                                        0, 32, "config_valid")),
                         &thisId);
  emlrtDestroyArray(&u);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *u
//                const emlrtMsgIdentifier *parentId
//                struct13_T &y
// Return Type  : void
//
static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, struct13_T &y)
{
  static const int32_T dims{0};
  static const char_T *fieldNames[14]{
      "code",        "deg_timer",     "loss_timer",  "posok_timer",
      "allok_timer", "last_accept_t", "have_accept", "init_time",
      "last_t",      "have_init",     "have_t",      "trans_count",
      "trans_from",  "trans_to"};
  emlrtMsgIdentifier thisId;
  thisId.fParent = parentId;
  thisId.bParentIsCell = false;
  emlrtCheckStructR2012b((emlrtConstCTX)&sp, parentId, u, 14,
                         (const char_T **)&fieldNames[0], 0U,
                         (const void *)&dims);
  thisId.fIdentifier = "code";
  y.code = g_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 0, "code")),
      &thisId);
  thisId.fIdentifier = "deg_timer";
  y.deg_timer = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 1, "deg_timer")),
      &thisId);
  thisId.fIdentifier = "loss_timer";
  y.loss_timer =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      2, "loss_timer")),
                       &thisId);
  thisId.fIdentifier = "posok_timer";
  y.posok_timer =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      3, "posok_timer")),
                       &thisId);
  thisId.fIdentifier = "allok_timer";
  y.allok_timer =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      4, "allok_timer")),
                       &thisId);
  thisId.fIdentifier = "last_accept_t";
  b_emlrt_marshallIn(sp,
                     emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 5,
                                                    "last_accept_t")),
                     &thisId, y.last_accept_t);
  thisId.fIdentifier = "have_accept";
  c_emlrt_marshallIn(sp,
                     emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 6,
                                                    "have_accept")),
                     &thisId, y.have_accept);
  thisId.fIdentifier = "init_time";
  y.init_time = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 7, "init_time")),
      &thisId);
  thisId.fIdentifier = "last_t";
  y.last_t = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 8, "last_t")),
      &thisId);
  thisId.fIdentifier = "have_init";
  y.have_init = b_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 9, "have_init")),
      &thisId);
  thisId.fIdentifier = "have_t";
  y.have_t = b_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 10, "have_t")),
      &thisId);
  thisId.fIdentifier = "trans_count";
  y.trans_count =
      e_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u,
                                                        0, 11, "trans_count")),
                         &thisId);
  thisId.fIdentifier = "trans_from";
  y.trans_from =
      g_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u,
                                                        0, 12, "trans_from")),
                         &thisId);
  thisId.fIdentifier = "trans_to";
  y.trans_to = g_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 13, "trans_to")),
      &thisId);
  emlrtDestroyArray(&u);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *u
//                const emlrtMsgIdentifier *parentId
//                struct2_T &y
// Return Type  : void
//
static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, struct2_T &y)
{
  static const int32_T dims{0};
  static const char_T *fieldNames[20]{"MAX_PATH_POINTS",
                                      "lookahead_distance",
                                      "desired_speed",
                                      "pitch_ref_max",
                                      "pitch_ref_rate_max",
                                      "dt_guidance",
                                      "dt_controller",
                                      "K_zdot",
                                      "K_gamma",
                                      "enable_alpha_hat",
                                      "k_beta",
                                      "closed_eps",
                                      "near_end_margin",
                                      "mono_back_max",
                                      "s_back_tol",
                                      "yaw_slew_max_rad_s",
                                      "r_ff_max_rad_s",
                                      "pitch_corr_max",
                                      "z_e_i_max",
                                      "alpha_hat_max"};
  emlrtMsgIdentifier thisId;
  thisId.fParent = parentId;
  thisId.bParentIsCell = false;
  emlrtCheckStructR2012b((emlrtConstCTX)&sp, parentId, u, 20,
                         (const char_T **)&fieldNames[0], 0U,
                         (const void *)&dims);
  thisId.fIdentifier = "MAX_PATH_POINTS";
  y.MAX_PATH_POINTS =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      0, "MAX_PATH_POINTS")),
                       &thisId);
  thisId.fIdentifier = "lookahead_distance";
  y.lookahead_distance =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      1, "lookahead_distance")),
                       &thisId);
  thisId.fIdentifier = "desired_speed";
  y.desired_speed =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      2, "desired_speed")),
                       &thisId);
  thisId.fIdentifier = "pitch_ref_max";
  y.pitch_ref_max =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      3, "pitch_ref_max")),
                       &thisId);
  thisId.fIdentifier = "pitch_ref_rate_max";
  y.pitch_ref_rate_max =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      4, "pitch_ref_rate_max")),
                       &thisId);
  thisId.fIdentifier = "dt_guidance";
  y.dt_guidance =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      5, "dt_guidance")),
                       &thisId);
  thisId.fIdentifier = "dt_controller";
  y.dt_controller =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      6, "dt_controller")),
                       &thisId);
  thisId.fIdentifier = "K_zdot";
  y.K_zdot = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 7, "K_zdot")),
      &thisId);
  thisId.fIdentifier = "K_gamma";
  y.K_gamma = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 8, "K_gamma")),
      &thisId);
  thisId.fIdentifier = "enable_alpha_hat";
  y.enable_alpha_hat =
      b_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b(
                             (emlrtConstCTX)&sp, u, 0, 9, "enable_alpha_hat")),
                         &thisId);
  thisId.fIdentifier = "k_beta";
  y.k_beta = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 10, "k_beta")),
      &thisId);
  thisId.fIdentifier = "closed_eps";
  y.closed_eps =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      11, "closed_eps")),
                       &thisId);
  thisId.fIdentifier = "near_end_margin";
  y.near_end_margin =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      12, "near_end_margin")),
                       &thisId);
  thisId.fIdentifier = "mono_back_max";
  y.mono_back_max =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      13, "mono_back_max")),
                       &thisId);
  thisId.fIdentifier = "s_back_tol";
  y.s_back_tol =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      14, "s_back_tol")),
                       &thisId);
  thisId.fIdentifier = "yaw_slew_max_rad_s";
  y.yaw_slew_max_rad_s =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b(
                           (emlrtConstCTX)&sp, u, 0, 15, "yaw_slew_max_rad_s")),
                       &thisId);
  thisId.fIdentifier = "r_ff_max_rad_s";
  y.r_ff_max_rad_s =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      16, "r_ff_max_rad_s")),
                       &thisId);
  thisId.fIdentifier = "pitch_corr_max";
  y.pitch_corr_max =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      17, "pitch_corr_max")),
                       &thisId);
  thisId.fIdentifier = "z_e_i_max";
  y.z_e_i_max =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      18, "z_e_i_max")),
                       &thisId);
  thisId.fIdentifier = "alpha_hat_max";
  y.alpha_hat_max =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      19, "alpha_hat_max")),
                       &thisId);
  emlrtDestroyArray(&u);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *u
//                const emlrtMsgIdentifier *parentId
//                uint32_T y[7]
// Return Type  : void
//
static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, uint32_T y[7])
{
  b_emlrt_marshallIn(sp, emlrtAlias(u), parentId, y);
  emlrtDestroyArray(&u);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *u
//                const emlrtMsgIdentifier *parentId
//                struct8_T &y
// Return Type  : void
//
static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, struct8_T &y)
{
  static const int32_T dims{0};
  static const char_T *fieldNames[9]{"G_nom",     "thr_B2",     "eps_dr_rad",
                                     "u_floor",   "t_warmup_s", "Np",
                                     "persist_s", "dt",         "config_valid"};
  emlrtMsgIdentifier thisId;
  thisId.fParent = parentId;
  thisId.bParentIsCell = false;
  emlrtCheckStructR2012b((emlrtConstCTX)&sp, parentId, u, 9,
                         (const char_T **)&fieldNames[0], 0U,
                         (const void *)&dims);
  thisId.fIdentifier = "G_nom";
  y.G_nom = emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 0, "G_nom")),
      &thisId);
  thisId.fIdentifier = "thr_B2";
  y.thr_B2 = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 1, "thr_B2")),
      &thisId);
  thisId.fIdentifier = "eps_dr_rad";
  y.eps_dr_rad =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      2, "eps_dr_rad")),
                       &thisId);
  thisId.fIdentifier = "u_floor";
  y.u_floor = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 3, "u_floor")),
      &thisId);
  thisId.fIdentifier = "t_warmup_s";
  y.t_warmup_s =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      4, "t_warmup_s")),
                       &thisId);
  thisId.fIdentifier = "Np";
  y.Np = emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 5, "Np")),
      &thisId);
  thisId.fIdentifier = "persist_s";
  y.persist_s = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 6, "persist_s")),
      &thisId);
  thisId.fIdentifier = "dt";
  y.dt = emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 7, "dt")),
      &thisId);
  thisId.fIdentifier = "config_valid";
  y.config_valid =
      b_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u,
                                                        0, 8, "config_valid")),
                         &thisId);
  emlrtDestroyArray(&u);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *u
//                const emlrtMsgIdentifier *parentId
//                struct1_T &y
// Return Type  : void
//
static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, struct1_T &y)
{
  static const int32_T dims{0};
  static const char_T *fieldNames[32]{"Kp_psi",
                                      "Kd_psi",
                                      "Kp_x",
                                      "Kp_roll",
                                      "Kp_angle",
                                      "Ki_angle",
                                      "Kp_rate",
                                      "Ki_rate",
                                      "Kaw_pitch",
                                      "Kd_rate",
                                      "Kd_damp",
                                      "delta_r_max",
                                      "delta_e_max",
                                      "thrust_max",
                                      "thrust_min",
                                      "thrust_trim",
                                      "trim_speed_table",
                                      "trim_elevator_table",
                                      "elevator_sign",
                                      "dt_controller",
                                      "tau_rate",
                                      "Muw",
                                      "Muuds",
                                      "lambda_muw_ff",
                                      "muw_ff_u_min",
                                      "muw_ff_u_lo",
                                      "muw_ff_u_hi",
                                      "muw_ff_clamp_deg",
                                      "delta_e_trim",
                                      "k_gamma_climb",
                                      "de_climb_lim",
                                      "slew_max_rad_s"};
  emlrtMsgIdentifier thisId;
  thisId.fParent = parentId;
  thisId.bParentIsCell = false;
  emlrtCheckStructR2012b((emlrtConstCTX)&sp, parentId, u, 32,
                         (const char_T **)&fieldNames[0], 0U,
                         (const void *)&dims);
  thisId.fIdentifier = "Kp_psi";
  y.Kp_psi = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 0, "Kp_psi")),
      &thisId);
  thisId.fIdentifier = "Kd_psi";
  y.Kd_psi = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 1, "Kd_psi")),
      &thisId);
  thisId.fIdentifier = "Kp_x";
  y.Kp_x = emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 2, "Kp_x")),
      &thisId);
  thisId.fIdentifier = "Kp_roll";
  y.Kp_roll = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 3, "Kp_roll")),
      &thisId);
  thisId.fIdentifier = "Kp_angle";
  y.Kp_angle = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 4, "Kp_angle")),
      &thisId);
  thisId.fIdentifier = "Ki_angle";
  y.Ki_angle = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 5, "Ki_angle")),
      &thisId);
  thisId.fIdentifier = "Kp_rate";
  y.Kp_rate = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 6, "Kp_rate")),
      &thisId);
  thisId.fIdentifier = "Ki_rate";
  y.Ki_rate = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 7, "Ki_rate")),
      &thisId);
  thisId.fIdentifier = "Kaw_pitch";
  y.Kaw_pitch = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 8, "Kaw_pitch")),
      &thisId);
  thisId.fIdentifier = "Kd_rate";
  y.Kd_rate = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 9, "Kd_rate")),
      &thisId);
  thisId.fIdentifier = "Kd_damp";
  y.Kd_damp = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 10, "Kd_damp")),
      &thisId);
  thisId.fIdentifier = "delta_r_max";
  y.delta_r_max =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      11, "delta_r_max")),
                       &thisId);
  thisId.fIdentifier = "delta_e_max";
  y.delta_e_max =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      12, "delta_e_max")),
                       &thisId);
  thisId.fIdentifier = "thrust_max";
  y.thrust_max =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      13, "thrust_max")),
                       &thisId);
  thisId.fIdentifier = "thrust_min";
  y.thrust_min =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      14, "thrust_min")),
                       &thisId);
  thisId.fIdentifier = "thrust_trim";
  y.thrust_trim =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      15, "thrust_trim")),
                       &thisId);
  thisId.fIdentifier = "trim_speed_table";
  emlrt_marshallIn(sp,
                   emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 16,
                                                  "trim_speed_table")),
                   &thisId, y.trim_speed_table);
  thisId.fIdentifier = "trim_elevator_table";
  emlrt_marshallIn(sp,
                   emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 17,
                                                  "trim_elevator_table")),
                   &thisId, y.trim_elevator_table);
  thisId.fIdentifier = "elevator_sign";
  y.elevator_sign =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      18, "elevator_sign")),
                       &thisId);
  thisId.fIdentifier = "dt_controller";
  y.dt_controller =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      19, "dt_controller")),
                       &thisId);
  thisId.fIdentifier = "tau_rate";
  y.tau_rate = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 20, "tau_rate")),
      &thisId);
  thisId.fIdentifier = "Muw";
  y.Muw = emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 21, "Muw")),
      &thisId);
  thisId.fIdentifier = "Muuds";
  y.Muuds = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 22, "Muuds")),
      &thisId);
  thisId.fIdentifier = "lambda_muw_ff";
  y.lambda_muw_ff =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      23, "lambda_muw_ff")),
                       &thisId);
  thisId.fIdentifier = "muw_ff_u_min";
  y.muw_ff_u_min =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      24, "muw_ff_u_min")),
                       &thisId);
  thisId.fIdentifier = "muw_ff_u_lo";
  y.muw_ff_u_lo =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      25, "muw_ff_u_lo")),
                       &thisId);
  thisId.fIdentifier = "muw_ff_u_hi";
  y.muw_ff_u_hi =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      26, "muw_ff_u_hi")),
                       &thisId);
  thisId.fIdentifier = "muw_ff_clamp_deg";
  y.muw_ff_clamp_deg =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      27, "muw_ff_clamp_deg")),
                       &thisId);
  thisId.fIdentifier = "delta_e_trim";
  y.delta_e_trim =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      28, "delta_e_trim")),
                       &thisId);
  thisId.fIdentifier = "k_gamma_climb";
  y.k_gamma_climb =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      29, "k_gamma_climb")),
                       &thisId);
  thisId.fIdentifier = "de_climb_lim";
  y.de_climb_lim =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      30, "de_climb_lim")),
                       &thisId);
  thisId.fIdentifier = "slew_max_rad_s";
  y.slew_max_rad_s =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      31, "slew_max_rad_s")),
                       &thisId);
  emlrtDestroyArray(&u);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *u
//                const emlrtMsgIdentifier *parentId
//                real_T y[4]
// Return Type  : void
//
static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, real_T y[4])
{
  i_emlrt_marshallIn(sp, emlrtAlias(u), parentId, y);
  emlrtDestroyArray(&u);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *u
//                const emlrtMsgIdentifier *parentId
//                struct5_T &y
// Return Type  : void
//
static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, struct5_T &y)
{
  static const int32_T dims{0};
  static const char_T *fieldNames[9]{
      "controller",  "guidance",    "navigation",       "availability",
      "fdir",        "safe_thrust", "guidance_divider", "arm_min_healthy_ticks",
      "config_valid"};
  emlrtMsgIdentifier thisId;
  thisId.fParent = parentId;
  thisId.bParentIsCell = false;
  emlrtCheckStructR2012b((emlrtConstCTX)&sp, parentId, u, 9,
                         (const char_T **)&fieldNames[0], 0U,
                         (const void *)&dims);
  thisId.fIdentifier = "controller";
  emlrt_marshallIn(sp,
                   emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 0,
                                                  "controller")),
                   &thisId, y.controller);
  thisId.fIdentifier = "guidance";
  emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 1, "guidance")),
      &thisId, y.guidance);
  thisId.fIdentifier = "navigation";
  emlrt_marshallIn(sp,
                   emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 2,
                                                  "navigation")),
                   &thisId, y.navigation);
  thisId.fIdentifier = "availability";
  emlrt_marshallIn(sp,
                   emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 3,
                                                  "availability")),
                   &thisId, y.availability);
  thisId.fIdentifier = "fdir";
  emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 4, "fdir")),
      &thisId, y.fdir);
  thisId.fIdentifier = "safe_thrust";
  y.safe_thrust =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      5, "safe_thrust")),
                       &thisId);
  thisId.fIdentifier = "guidance_divider";
  y.guidance_divider =
      e_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b(
                             (emlrtConstCTX)&sp, u, 0, 6, "guidance_divider")),
                         &thisId);
  thisId.fIdentifier = "arm_min_healthy_ticks";
  y.arm_min_healthy_ticks = e_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 7,
                                     "arm_min_healthy_ticks")),
      &thisId);
  thisId.fIdentifier = "config_valid";
  y.config_valid =
      b_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u,
                                                        0, 8, "config_valid")),
                         &thisId);
  emlrtDestroyArray(&u);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *b_nullptr
//                const char_T *identifier
//                struct0_T &y
// Return Type  : void
//
static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *b_nullptr,
                             const char_T *identifier, struct0_T &y)
{
  emlrtMsgIdentifier thisId;
  thisId.fIdentifier = const_cast<const char_T *>(identifier);
  thisId.fParent = nullptr;
  thisId.bParentIsCell = false;
  emlrt_marshallIn(sp, emlrtAlias(b_nullptr), &thisId, y);
  emlrtDestroyArray(&b_nullptr);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *u
//                const emlrtMsgIdentifier *parentId
//                struct0_T &y
// Return Type  : void
//
static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, struct0_T &y)
{
  static const int32_T dims{0};
  static const char_T *fieldNames[5]{"controller", "guidance", "availability",
                                     "fdir", "safe_thrust"};
  emlrtMsgIdentifier thisId;
  thisId.fParent = parentId;
  thisId.bParentIsCell = false;
  emlrtCheckStructR2012b((emlrtConstCTX)&sp, parentId, u, 5,
                         (const char_T **)&fieldNames[0], 0U,
                         (const void *)&dims);
  thisId.fIdentifier = "controller";
  emlrt_marshallIn(sp,
                   emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 0,
                                                  "controller")),
                   &thisId, y.controller);
  thisId.fIdentifier = "guidance";
  emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 1, "guidance")),
      &thisId, y.guidance);
  thisId.fIdentifier = "availability";
  emlrt_marshallIn(sp,
                   emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 2,
                                                  "availability")),
                   &thisId, y.availability);
  thisId.fIdentifier = "fdir";
  y.fdir = d_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 3, "fdir")),
      &thisId);
  thisId.fIdentifier = "safe_thrust";
  y.safe_thrust =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      4, "safe_thrust")),
                       &thisId);
  emlrtDestroyArray(&u);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *b_nullptr
//                const char_T *identifier
//                struct5_T &y
// Return Type  : void
//
static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *b_nullptr,
                             const char_T *identifier, struct5_T &y)
{
  emlrtMsgIdentifier thisId;
  thisId.fIdentifier = const_cast<const char_T *>(identifier);
  thisId.fParent = nullptr;
  thisId.bParentIsCell = false;
  emlrt_marshallIn(sp, emlrtAlias(b_nullptr), &thisId, y);
  emlrtDestroyArray(&b_nullptr);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *u
//                const emlrtMsgIdentifier *parentId
//                struct12_T &y
// Return Type  : void
//
static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, struct12_T &y)
{
  static const int32_T dims{0};
  static const char_T *fieldNames[15]{"initialized",
                                      "p",
                                      "v",
                                      "q",
                                      "bg",
                                      "ba",
                                      "c",
                                      "P",
                                      "last_seq",
                                      "have_seq",
                                      "last_ts",
                                      "have_ts",
                                      "last_accept_t",
                                      "have_accept_t",
                                      "est_seq"};
  emlrtMsgIdentifier thisId;
  thisId.fParent = parentId;
  thisId.bParentIsCell = false;
  emlrtCheckStructR2012b((emlrtConstCTX)&sp, parentId, u, 15,
                         (const char_T **)&fieldNames[0], 0U,
                         (const void *)&dims);
  thisId.fIdentifier = "initialized";
  y.initialized =
      b_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u,
                                                        0, 0, "initialized")),
                         &thisId);
  thisId.fIdentifier = "p";
  d_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 1, "p")),
      &thisId, y.p);
  thisId.fIdentifier = "v";
  d_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 2, "v")),
      &thisId, y.v);
  thisId.fIdentifier = "q";
  e_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 3, "q")),
      &thisId, y.q);
  thisId.fIdentifier = "bg";
  d_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 4, "bg")),
      &thisId, y.bg);
  thisId.fIdentifier = "ba";
  d_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 5, "ba")),
      &thisId, y.ba);
  thisId.fIdentifier = "c";
  d_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 6, "c")),
      &thisId, y.c);
  thisId.fIdentifier = "P";
  f_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 7, "P")),
      &thisId, y.P);
  thisId.fIdentifier = "last_seq";
  emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 8, "last_seq")),
      &thisId, y.last_seq);
  thisId.fIdentifier = "have_seq";
  c_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 9, "have_seq")),
      &thisId, y.have_seq);
  thisId.fIdentifier = "last_ts";
  b_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 10, "last_ts")),
      &thisId, y.last_ts);
  thisId.fIdentifier = "have_ts";
  c_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 11, "have_ts")),
      &thisId, y.have_ts);
  thisId.fIdentifier = "last_accept_t";
  b_emlrt_marshallIn(sp,
                     emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                    12, "last_accept_t")),
                     &thisId, y.last_accept_t);
  thisId.fIdentifier = "have_accept_t";
  c_emlrt_marshallIn(sp,
                     emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                    13, "have_accept_t")),
                     &thisId, y.have_accept_t);
  thisId.fIdentifier = "est_seq";
  y.est_seq = e_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 14, "est_seq")),
      &thisId);
  emlrtDestroyArray(&u);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *u
//                const emlrtMsgIdentifier *parentId
//                struct11_T &y
// Return Type  : void
//
static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, struct11_T &y)
{
  static const int32_T dims{0};
  static const char_T *fieldNames[17]{
      "initialized", "s_prog",        "yaw_cont",     "pitch_f",
      "z_e_f",       "z_e_i",         "zd_e_f",       "eg_f",
      "alpha_hat",   "kappa_f",       "chi_f",        "yaw_out",
      "pitch_out",   "have_yaw_cont", "have_pitch_f", "have_chi_f",
      "have_yaw_out"};
  emlrtMsgIdentifier thisId;
  thisId.fParent = parentId;
  thisId.bParentIsCell = false;
  emlrtCheckStructR2012b((emlrtConstCTX)&sp, parentId, u, 17,
                         (const char_T **)&fieldNames[0], 0U,
                         (const void *)&dims);
  thisId.fIdentifier = "initialized";
  y.initialized =
      b_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u,
                                                        0, 0, "initialized")),
                         &thisId);
  thisId.fIdentifier = "s_prog";
  y.s_prog = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 1, "s_prog")),
      &thisId);
  thisId.fIdentifier = "yaw_cont";
  y.yaw_cont = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 2, "yaw_cont")),
      &thisId);
  thisId.fIdentifier = "pitch_f";
  y.pitch_f = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 3, "pitch_f")),
      &thisId);
  thisId.fIdentifier = "z_e_f";
  y.z_e_f = emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 4, "z_e_f")),
      &thisId);
  thisId.fIdentifier = "z_e_i";
  y.z_e_i = emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 5, "z_e_i")),
      &thisId);
  thisId.fIdentifier = "zd_e_f";
  y.zd_e_f = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 6, "zd_e_f")),
      &thisId);
  thisId.fIdentifier = "eg_f";
  y.eg_f = emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 7, "eg_f")),
      &thisId);
  thisId.fIdentifier = "alpha_hat";
  y.alpha_hat = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 8, "alpha_hat")),
      &thisId);
  thisId.fIdentifier = "kappa_f";
  y.kappa_f = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 9, "kappa_f")),
      &thisId);
  thisId.fIdentifier = "chi_f";
  y.chi_f = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 10, "chi_f")),
      &thisId);
  thisId.fIdentifier = "yaw_out";
  y.yaw_out = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 11, "yaw_out")),
      &thisId);
  thisId.fIdentifier = "pitch_out";
  y.pitch_out =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      12, "pitch_out")),
                       &thisId);
  thisId.fIdentifier = "have_yaw_cont";
  y.have_yaw_cont =
      b_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b(
                             (emlrtConstCTX)&sp, u, 0, 13, "have_yaw_cont")),
                         &thisId);
  thisId.fIdentifier = "have_pitch_f";
  y.have_pitch_f =
      b_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u,
                                                        0, 14, "have_pitch_f")),
                         &thisId);
  thisId.fIdentifier = "have_chi_f";
  y.have_chi_f =
      b_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u,
                                                        0, 15, "have_chi_f")),
                         &thisId);
  thisId.fIdentifier = "have_yaw_out";
  y.have_yaw_out =
      b_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u,
                                                        0, 16, "have_yaw_out")),
                         &thisId);
  emlrtDestroyArray(&u);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *u
//                const emlrtMsgIdentifier *parentId
//                struct7_T &y
// Return Type  : void
//
static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, struct7_T &y)
{
  static const int32_T dims{0};
  static const char_T *fieldNames[13]{
      "T_degrade",   "T_lost",    "T_reacq",     "T_clear", "T_settle",
      "tol_time",    "k_fresh",   "tau_floor",   "present", "period",
      "stale_limit", "tau_fresh", "config_valid"};
  emlrtMsgIdentifier thisId;
  thisId.fParent = parentId;
  thisId.bParentIsCell = false;
  emlrtCheckStructR2012b((emlrtConstCTX)&sp, parentId, u, 13,
                         (const char_T **)&fieldNames[0], 0U,
                         (const void *)&dims);
  thisId.fIdentifier = "T_degrade";
  y.T_degrade = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 0, "T_degrade")),
      &thisId);
  thisId.fIdentifier = "T_lost";
  y.T_lost = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 1, "T_lost")),
      &thisId);
  thisId.fIdentifier = "T_reacq";
  y.T_reacq = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 2, "T_reacq")),
      &thisId);
  thisId.fIdentifier = "T_clear";
  y.T_clear = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 3, "T_clear")),
      &thisId);
  thisId.fIdentifier = "T_settle";
  y.T_settle = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 4, "T_settle")),
      &thisId);
  thisId.fIdentifier = "tol_time";
  y.tol_time = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 5, "tol_time")),
      &thisId);
  thisId.fIdentifier = "k_fresh";
  y.k_fresh = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 6, "k_fresh")),
      &thisId);
  thisId.fIdentifier = "tau_floor";
  y.tau_floor = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 7, "tau_floor")),
      &thisId);
  thisId.fIdentifier = "present";
  c_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 8, "present")),
      &thisId, y.present);
  thisId.fIdentifier = "period";
  b_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 9, "period")),
      &thisId, y.period);
  thisId.fIdentifier = "stale_limit";
  b_emlrt_marshallIn(sp,
                     emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                    10, "stale_limit")),
                     &thisId, y.stale_limit);
  thisId.fIdentifier = "tau_fresh";
  b_emlrt_marshallIn(sp,
                     emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                    11, "tau_fresh")),
                     &thisId, y.tau_fresh);
  thisId.fIdentifier = "config_valid";
  y.config_valid =
      b_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u,
                                                        0, 12, "config_valid")),
                         &thisId);
  emlrtDestroyArray(&u);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *b_nullptr
//                const char_T *identifier
//                struct9_T &y
// Return Type  : void
//
static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *b_nullptr,
                             const char_T *identifier, struct9_T &y)
{
  emlrtMsgIdentifier thisId;
  thisId.fIdentifier = const_cast<const char_T *>(identifier);
  thisId.fParent = nullptr;
  thisId.bParentIsCell = false;
  emlrt_marshallIn(sp, emlrtAlias(b_nullptr), &thisId, y);
  emlrtDestroyArray(&b_nullptr);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *u
//                const emlrtMsgIdentifier *parentId
//                struct9_T &y
// Return Type  : void
//
static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, struct9_T &y)
{
  static const int32_T dims{0};
  static const char_T *fieldNames[19]{"controller",
                                      "guidance",
                                      "navigation",
                                      "availability",
                                      "fdir",
                                      "tick_count",
                                      "have_tick",
                                      "last_tick_seq",
                                      "last_t",
                                      "progress_index",
                                      "yaw",
                                      "pitch",
                                      "u",
                                      "r_ff",
                                      "pitch_dot",
                                      "guidance_ready",
                                      "arm_state",
                                      "healthy_streak",
                                      "fault_bits_latched"};
  emlrtMsgIdentifier thisId;
  thisId.fParent = parentId;
  thisId.bParentIsCell = false;
  emlrtCheckStructR2012b((emlrtConstCTX)&sp, parentId, u, 19,
                         (const char_T **)&fieldNames[0], 0U,
                         (const void *)&dims);
  thisId.fIdentifier = "controller";
  y.controller =
      f_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u,
                                                        0, 0, "controller")),
                         &thisId);
  thisId.fIdentifier = "guidance";
  emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 1, "guidance")),
      &thisId, y.guidance);
  thisId.fIdentifier = "navigation";
  emlrt_marshallIn(sp,
                   emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 2,
                                                  "navigation")),
                   &thisId, y.navigation);
  thisId.fIdentifier = "availability";
  emlrt_marshallIn(sp,
                   emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 3,
                                                  "availability")),
                   &thisId, y.availability);
  thisId.fIdentifier = "fdir";
  y.fdir = h_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 4, "fdir")),
      &thisId);
  thisId.fIdentifier = "tick_count";
  y.tick_count =
      e_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u,
                                                        0, 5, "tick_count")),
                         &thisId);
  thisId.fIdentifier = "have_tick";
  y.have_tick = b_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 6, "have_tick")),
      &thisId);
  thisId.fIdentifier = "last_tick_seq";
  y.last_tick_seq =
      e_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u,
                                                        0, 7, "last_tick_seq")),
                         &thisId);
  thisId.fIdentifier = "last_t";
  y.last_t = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 8, "last_t")),
      &thisId);
  thisId.fIdentifier = "progress_index";
  y.progress_index =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      9, "progress_index")),
                       &thisId);
  thisId.fIdentifier = "yaw";
  y.yaw = emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 10, "yaw")),
      &thisId);
  thisId.fIdentifier = "pitch";
  y.pitch = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 11, "pitch")),
      &thisId);
  thisId.fIdentifier = "u";
  y.u = emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 12, "u")),
      &thisId);
  thisId.fIdentifier = "r_ff";
  y.r_ff = emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 13, "r_ff")),
      &thisId);
  thisId.fIdentifier = "pitch_dot";
  y.pitch_dot =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      14, "pitch_dot")),
                       &thisId);
  thisId.fIdentifier = "guidance_ready";
  y.guidance_ready =
      b_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b(
                             (emlrtConstCTX)&sp, u, 0, 15, "guidance_ready")),
                         &thisId);
  thisId.fIdentifier = "arm_state";
  y.arm_state =
      g_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u,
                                                        0, 16, "arm_state")),
                         &thisId);
  thisId.fIdentifier = "healthy_streak";
  y.healthy_streak =
      e_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b(
                             (emlrtConstCTX)&sp, u, 0, 17, "healthy_streak")),
                         &thisId);
  thisId.fIdentifier = "fault_bits_latched";
  y.fault_bits_latched = e_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 18,
                                     "fault_bits_latched")),
      &thisId);
  emlrtDestroyArray(&u);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *b_nullptr
//                const char_T *identifier
//                struct15_T &y
// Return Type  : void
//
static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *b_nullptr,
                             const char_T *identifier, struct15_T &y)
{
  emlrtMsgIdentifier thisId;
  thisId.fIdentifier = const_cast<const char_T *>(identifier);
  thisId.fParent = nullptr;
  thisId.bParentIsCell = false;
  emlrt_marshallIn(sp, emlrtAlias(b_nullptr), &thisId, y);
  emlrtDestroyArray(&b_nullptr);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *u
//                const emlrtMsgIdentifier *parentId
//                struct15_T &y
// Return Type  : void
//
static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, struct15_T &y)
{
  static const int32_T dims{0};
  static const char_T *fieldNames[11]{
      "t",           "tick_seq",       "sample_valid",
      "arm_request", "disarm_request", "kill_asserted",
      "nav",         "path_pad",       "n_path",
      "body_rates",  "accepted"};
  emlrtMsgIdentifier thisId;
  thisId.fParent = parentId;
  thisId.bParentIsCell = false;
  emlrtCheckStructR2012b((emlrtConstCTX)&sp, parentId, u, 11,
                         (const char_T **)&fieldNames[0], 0U,
                         (const void *)&dims);
  thisId.fIdentifier = "t";
  y.t = emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 0, "t")),
      &thisId);
  thisId.fIdentifier = "tick_seq";
  y.tick_seq = e_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 1, "tick_seq")),
      &thisId);
  thisId.fIdentifier = "sample_valid";
  y.sample_valid =
      b_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u,
                                                        0, 2, "sample_valid")),
                         &thisId);
  thisId.fIdentifier = "arm_request";
  y.arm_request =
      b_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u,
                                                        0, 3, "arm_request")),
                         &thisId);
  thisId.fIdentifier = "disarm_request";
  y.disarm_request =
      b_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b(
                             (emlrtConstCTX)&sp, u, 0, 4, "disarm_request")),
                         &thisId);
  thisId.fIdentifier = "kill_asserted";
  y.kill_asserted =
      b_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u,
                                                        0, 5, "kill_asserted")),
                         &thisId);
  thisId.fIdentifier = "nav";
  emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 6, "nav")),
      &thisId, y.nav);
  thisId.fIdentifier = "path_pad";
  h_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 7, "path_pad")),
      &thisId, y.path_pad);
  thisId.fIdentifier = "n_path";
  y.n_path = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 8, "n_path")),
      &thisId);
  thisId.fIdentifier = "body_rates";
  d_emlrt_marshallIn(sp,
                     emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 9,
                                                    "body_rates")),
                     &thisId, y.body_rates);
  thisId.fIdentifier = "accepted";
  c_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 10, "accepted")),
      &thisId, y.accepted);
  emlrtDestroyArray(&u);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *u
//                const emlrtMsgIdentifier *parentId
//                struct16_T &y
// Return Type  : void
//
static void emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                             const emlrtMsgIdentifier *parentId, struct16_T &y)
{
  static const int32_T dims{0};
  static const char_T *fieldNames[31]{"op",
                                      "sample_valid",
                                      "t",
                                      "init_gyro",
                                      "init_accel",
                                      "init_depth",
                                      "init_heading",
                                      "init_ins_vel",
                                      "init_timestamp",
                                      "init_seq",
                                      "abs_position_present",
                                      "gyro",
                                      "accel",
                                      "gyro_timestamp",
                                      "accel_timestamp",
                                      "gyro_seq",
                                      "accel_seq",
                                      "channel",
                                      "dim",
                                      "present",
                                      "packet_valid",
                                      "status",
                                      "value",
                                      "timestamp",
                                      "quality",
                                      "stale_age",
                                      "bound_lo",
                                      "bound_hi",
                                      "q_nom",
                                      "stale_limit_s",
                                      "seq"};
  emlrtMsgIdentifier thisId;
  thisId.fParent = parentId;
  thisId.bParentIsCell = false;
  emlrtCheckStructR2012b((emlrtConstCTX)&sp, parentId, u, 31,
                         (const char_T **)&fieldNames[0], 0U,
                         (const void *)&dims);
  thisId.fIdentifier = "op";
  y.op = g_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 0, "op")),
      &thisId);
  thisId.fIdentifier = "sample_valid";
  y.sample_valid =
      b_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u,
                                                        0, 1, "sample_valid")),
                         &thisId);
  thisId.fIdentifier = "t";
  y.t = emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 2, "t")),
      &thisId);
  thisId.fIdentifier = "init_gyro";
  d_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 3, "init_gyro")),
      &thisId, y.init_gyro);
  thisId.fIdentifier = "init_accel";
  d_emlrt_marshallIn(sp,
                     emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 4,
                                                    "init_accel")),
                     &thisId, y.init_accel);
  thisId.fIdentifier = "init_depth";
  y.init_depth =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      5, "init_depth")),
                       &thisId);
  thisId.fIdentifier = "init_heading";
  y.init_heading =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      6, "init_heading")),
                       &thisId);
  thisId.fIdentifier = "init_ins_vel";
  d_emlrt_marshallIn(sp,
                     emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 7,
                                                    "init_ins_vel")),
                     &thisId, y.init_ins_vel);
  thisId.fIdentifier = "init_timestamp";
  g_emlrt_marshallIn(sp,
                     emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 8,
                                                    "init_timestamp")),
                     &thisId, y.init_timestamp);
  thisId.fIdentifier = "init_seq";
  g_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 9, "init_seq")),
      &thisId, y.init_seq);
  thisId.fIdentifier = "abs_position_present";
  y.abs_position_present = b_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 10,
                                     "abs_position_present")),
      &thisId);
  thisId.fIdentifier = "gyro";
  d_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 11, "gyro")),
      &thisId, y.gyro);
  thisId.fIdentifier = "accel";
  d_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 12, "accel")),
      &thisId, y.accel);
  thisId.fIdentifier = "gyro_timestamp";
  y.gyro_timestamp =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      13, "gyro_timestamp")),
                       &thisId);
  thisId.fIdentifier = "accel_timestamp";
  y.accel_timestamp =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      14, "accel_timestamp")),
                       &thisId);
  thisId.fIdentifier = "gyro_seq";
  y.gyro_seq = e_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 15, "gyro_seq")),
      &thisId);
  thisId.fIdentifier = "accel_seq";
  y.accel_seq =
      e_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u,
                                                        0, 16, "accel_seq")),
                         &thisId);
  thisId.fIdentifier = "channel";
  y.channel = g_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 17, "channel")),
      &thisId);
  thisId.fIdentifier = "dim";
  y.dim = g_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 18, "dim")),
      &thisId);
  thisId.fIdentifier = "present";
  y.present = b_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 19, "present")),
      &thisId);
  thisId.fIdentifier = "packet_valid";
  y.packet_valid =
      b_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u,
                                                        0, 20, "packet_valid")),
                         &thisId);
  thisId.fIdentifier = "status";
  y.status = g_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 21, "status")),
      &thisId);
  thisId.fIdentifier = "value";
  d_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 22, "value")),
      &thisId, y.value);
  thisId.fIdentifier = "timestamp";
  y.timestamp =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      23, "timestamp")),
                       &thisId);
  thisId.fIdentifier = "quality";
  y.quality = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 24, "quality")),
      &thisId);
  thisId.fIdentifier = "stale_age";
  y.stale_age =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      25, "stale_age")),
                       &thisId);
  thisId.fIdentifier = "bound_lo";
  d_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 26, "bound_lo")),
      &thisId, y.bound_lo);
  thisId.fIdentifier = "bound_hi";
  d_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 27, "bound_hi")),
      &thisId, y.bound_hi);
  thisId.fIdentifier = "q_nom";
  y.q_nom = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 28, "q_nom")),
      &thisId);
  thisId.fIdentifier = "stale_limit_s";
  y.stale_limit_s =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      29, "stale_limit_s")),
                       &thisId);
  thisId.fIdentifier = "seq";
  y.seq = e_emlrt_marshallIn(
      sp, emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 30, "seq")),
      &thisId);
  emlrtDestroyArray(&u);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *u
//                const emlrtMsgIdentifier *parentId
// Return Type  : real_T
//
static real_T emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId)
{
  real_T y;
  y = i_emlrt_marshallIn(sp, emlrtAlias(u), parentId);
  emlrtDestroyArray(&u);
  return y;
}

//
// Arguments    : const struct13_T &u
// Return Type  : const mxArray *
//
static const mxArray *emlrt_marshallOut(const struct13_T &u)
{
  static const int32_T i{7};
  static const int32_T i1{7};
  static const char_T *sv[14]{"code",        "deg_timer",   "loss_timer",
                              "posok_timer", "allok_timer", "last_accept_t",
                              "have_accept", "init_time",   "last_t",
                              "have_init",   "have_t",      "trans_count",
                              "trans_from",  "trans_to"};
  const mxArray *b_y;
  const mxArray *c_y;
  const mxArray *d_y;
  const mxArray *e_y;
  const mxArray *f_y;
  const mxArray *g_y;
  const mxArray *h_y;
  const mxArray *i_y;
  const mxArray *j_y;
  const mxArray *k_y;
  const mxArray *l_y;
  const mxArray *m;
  const mxArray *m_y;
  const mxArray *n_y;
  const mxArray *o_y;
  const mxArray *y;
  real_T *pData;
  y = nullptr;
  emlrtAssign(&y, emlrtCreateStructMatrix(1, 1, 14, (const char_T **)&sv[0]));
  b_y = nullptr;
  m = emlrtCreateNumericMatrix(1, 1, mxUINT8_CLASS, mxREAL);
  *static_cast<uint8_T *>(emlrtMxGetData(m)) = u.code;
  emlrtAssign(&b_y, m);
  emlrtSetFieldR2017b(y, 0, "code", b_y, 0);
  c_y = nullptr;
  m = emlrtCreateDoubleScalar(u.deg_timer);
  emlrtAssign(&c_y, m);
  emlrtSetFieldR2017b(y, 0, "deg_timer", c_y, 1);
  d_y = nullptr;
  m = emlrtCreateDoubleScalar(u.loss_timer);
  emlrtAssign(&d_y, m);
  emlrtSetFieldR2017b(y, 0, "loss_timer", d_y, 2);
  e_y = nullptr;
  m = emlrtCreateDoubleScalar(u.posok_timer);
  emlrtAssign(&e_y, m);
  emlrtSetFieldR2017b(y, 0, "posok_timer", e_y, 3);
  f_y = nullptr;
  m = emlrtCreateDoubleScalar(u.allok_timer);
  emlrtAssign(&f_y, m);
  emlrtSetFieldR2017b(y, 0, "allok_timer", f_y, 4);
  g_y = nullptr;
  m = emlrtCreateNumericArray(1, (const void *)&i, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  for (int32_T b_i{0}; b_i < 7; b_i++) {
    pData[b_i] = u.last_accept_t[b_i];
  }
  emlrtAssign(&g_y, m);
  emlrtSetFieldR2017b(y, 0, "last_accept_t", g_y, 5);
  h_y = nullptr;
  m = emlrtCreateLogicalArray(1, &i1);
  emlrtInitLogicalArray(7, m, &u.have_accept[0]);
  emlrtAssign(&h_y, m);
  emlrtSetFieldR2017b(y, 0, "have_accept", h_y, 6);
  i_y = nullptr;
  m = emlrtCreateDoubleScalar(u.init_time);
  emlrtAssign(&i_y, m);
  emlrtSetFieldR2017b(y, 0, "init_time", i_y, 7);
  j_y = nullptr;
  m = emlrtCreateDoubleScalar(u.last_t);
  emlrtAssign(&j_y, m);
  emlrtSetFieldR2017b(y, 0, "last_t", j_y, 8);
  k_y = nullptr;
  m = emlrtCreateLogicalScalar(u.have_init);
  emlrtAssign(&k_y, m);
  emlrtSetFieldR2017b(y, 0, "have_init", k_y, 9);
  l_y = nullptr;
  m = emlrtCreateLogicalScalar(u.have_t);
  emlrtAssign(&l_y, m);
  emlrtSetFieldR2017b(y, 0, "have_t", l_y, 10);
  m_y = nullptr;
  m = emlrtCreateNumericMatrix(1, 1, mxUINT32_CLASS, mxREAL);
  *static_cast<uint32_T *>(emlrtMxGetData(m)) = u.trans_count;
  emlrtAssign(&m_y, m);
  emlrtSetFieldR2017b(y, 0, "trans_count", m_y, 11);
  n_y = nullptr;
  m = emlrtCreateNumericMatrix(1, 1, mxUINT8_CLASS, mxREAL);
  *static_cast<uint8_T *>(emlrtMxGetData(m)) = u.trans_from;
  emlrtAssign(&n_y, m);
  emlrtSetFieldR2017b(y, 0, "trans_from", n_y, 12);
  o_y = nullptr;
  m = emlrtCreateNumericMatrix(1, 1, mxUINT8_CLASS, mxREAL);
  *static_cast<uint8_T *>(emlrtMxGetData(m)) = u.trans_to;
  emlrtAssign(&o_y, m);
  emlrtSetFieldR2017b(y, 0, "trans_to", o_y, 13);
  return y;
}

//
// Arguments    : const struct17_T &u
// Return Type  : const mxArray *
//
static const mxArray *emlrt_marshallOut(const struct17_T &u)
{
  static const int32_T i{3};
  static const int32_T i1{3};
  static const int32_T i2{3};
  static const int32_T i3{3};
  static const char_T *sv[36]{"delta_r",
                              "delta_e",
                              "thrust",
                              "command_valid",
                              "arm_state",
                              "ready",
                              "healthy_streak",
                              "health_bits",
                              "fault_bits_latched",
                              "tick_count",
                              "yaw",
                              "pitch",
                              "u",
                              "r_ff",
                              "pitch_dot",
                              "progress_index",
                              "guidance_due",
                              "guidance_ready",
                              "nav_p",
                              "nav_v",
                              "nav_euler",
                              "nav_vel_body_water",
                              "nav_valid",
                              "nav_initialized",
                              "nav_health_bits",
                              "availability_state",
                              "availability_health_bits",
                              "fdir_residual",
                              "fdir_anomaly_latched",
                              "fdir_health_bits",
                              "ctrl_delta_r",
                              "ctrl_delta_e",
                              "ctrl_thrust",
                              "physical_io_written",
                              "actuator_isolated",
                              "abort_requested"};
  const mxArray *ab_y;
  const mxArray *b_y;
  const mxArray *bb_y;
  const mxArray *c_y;
  const mxArray *cb_y;
  const mxArray *d_y;
  const mxArray *db_y;
  const mxArray *e_y;
  const mxArray *eb_y;
  const mxArray *f_y;
  const mxArray *fb_y;
  const mxArray *g_y;
  const mxArray *gb_y;
  const mxArray *h_y;
  const mxArray *hb_y;
  const mxArray *i_y;
  const mxArray *ib_y;
  const mxArray *j_y;
  const mxArray *jb_y;
  const mxArray *k_y;
  const mxArray *kb_y;
  const mxArray *l_y;
  const mxArray *lb_y;
  const mxArray *m;
  const mxArray *m_y;
  const mxArray *n_y;
  const mxArray *o_y;
  const mxArray *p_y;
  const mxArray *q_y;
  const mxArray *r_y;
  const mxArray *s_y;
  const mxArray *t_y;
  const mxArray *u_y;
  const mxArray *v_y;
  const mxArray *w_y;
  const mxArray *x_y;
  const mxArray *y;
  const mxArray *y_y;
  real_T *pData;
  y = nullptr;
  emlrtAssign(&y, emlrtCreateStructMatrix(1, 1, 36, (const char_T **)&sv[0]));
  b_y = nullptr;
  m = emlrtCreateDoubleScalar(u.delta_r);
  emlrtAssign(&b_y, m);
  emlrtSetFieldR2017b(y, 0, "delta_r", b_y, 0);
  c_y = nullptr;
  m = emlrtCreateDoubleScalar(u.delta_e);
  emlrtAssign(&c_y, m);
  emlrtSetFieldR2017b(y, 0, "delta_e", c_y, 1);
  d_y = nullptr;
  m = emlrtCreateDoubleScalar(u.thrust);
  emlrtAssign(&d_y, m);
  emlrtSetFieldR2017b(y, 0, "thrust", d_y, 2);
  e_y = nullptr;
  m = emlrtCreateLogicalScalar(u.command_valid);
  emlrtAssign(&e_y, m);
  emlrtSetFieldR2017b(y, 0, "command_valid", e_y, 3);
  f_y = nullptr;
  m = emlrtCreateNumericMatrix(1, 1, mxUINT8_CLASS, mxREAL);
  *static_cast<uint8_T *>(emlrtMxGetData(m)) = u.arm_state;
  emlrtAssign(&f_y, m);
  emlrtSetFieldR2017b(y, 0, "arm_state", f_y, 4);
  g_y = nullptr;
  m = emlrtCreateLogicalScalar(u.ready);
  emlrtAssign(&g_y, m);
  emlrtSetFieldR2017b(y, 0, "ready", g_y, 5);
  h_y = nullptr;
  m = emlrtCreateNumericMatrix(1, 1, mxUINT32_CLASS, mxREAL);
  *static_cast<uint32_T *>(emlrtMxGetData(m)) = u.healthy_streak;
  emlrtAssign(&h_y, m);
  emlrtSetFieldR2017b(y, 0, "healthy_streak", h_y, 6);
  i_y = nullptr;
  m = emlrtCreateNumericMatrix(1, 1, mxUINT32_CLASS, mxREAL);
  *static_cast<uint32_T *>(emlrtMxGetData(m)) = u.health_bits;
  emlrtAssign(&i_y, m);
  emlrtSetFieldR2017b(y, 0, "health_bits", i_y, 7);
  j_y = nullptr;
  m = emlrtCreateNumericMatrix(1, 1, mxUINT32_CLASS, mxREAL);
  *static_cast<uint32_T *>(emlrtMxGetData(m)) = u.fault_bits_latched;
  emlrtAssign(&j_y, m);
  emlrtSetFieldR2017b(y, 0, "fault_bits_latched", j_y, 8);
  k_y = nullptr;
  m = emlrtCreateNumericMatrix(1, 1, mxUINT32_CLASS, mxREAL);
  *static_cast<uint32_T *>(emlrtMxGetData(m)) = u.tick_count;
  emlrtAssign(&k_y, m);
  emlrtSetFieldR2017b(y, 0, "tick_count", k_y, 9);
  l_y = nullptr;
  m = emlrtCreateDoubleScalar(u.yaw);
  emlrtAssign(&l_y, m);
  emlrtSetFieldR2017b(y, 0, "yaw", l_y, 10);
  m_y = nullptr;
  m = emlrtCreateDoubleScalar(u.pitch);
  emlrtAssign(&m_y, m);
  emlrtSetFieldR2017b(y, 0, "pitch", m_y, 11);
  n_y = nullptr;
  m = emlrtCreateDoubleScalar(u.u);
  emlrtAssign(&n_y, m);
  emlrtSetFieldR2017b(y, 0, "u", n_y, 12);
  o_y = nullptr;
  m = emlrtCreateDoubleScalar(u.r_ff);
  emlrtAssign(&o_y, m);
  emlrtSetFieldR2017b(y, 0, "r_ff", o_y, 13);
  p_y = nullptr;
  m = emlrtCreateDoubleScalar(u.pitch_dot);
  emlrtAssign(&p_y, m);
  emlrtSetFieldR2017b(y, 0, "pitch_dot", p_y, 14);
  q_y = nullptr;
  m = emlrtCreateDoubleScalar(u.progress_index);
  emlrtAssign(&q_y, m);
  emlrtSetFieldR2017b(y, 0, "progress_index", q_y, 15);
  r_y = nullptr;
  m = emlrtCreateLogicalScalar(u.guidance_due);
  emlrtAssign(&r_y, m);
  emlrtSetFieldR2017b(y, 0, "guidance_due", r_y, 16);
  s_y = nullptr;
  m = emlrtCreateLogicalScalar(u.guidance_ready);
  emlrtAssign(&s_y, m);
  emlrtSetFieldR2017b(y, 0, "guidance_ready", s_y, 17);
  t_y = nullptr;
  m = emlrtCreateNumericArray(1, (const void *)&i, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  pData[0] = u.nav_p[0];
  pData[1] = u.nav_p[1];
  pData[2] = u.nav_p[2];
  emlrtAssign(&t_y, m);
  emlrtSetFieldR2017b(y, 0, "nav_p", t_y, 18);
  u_y = nullptr;
  m = emlrtCreateNumericArray(1, (const void *)&i1, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  pData[0] = u.nav_v[0];
  pData[1] = u.nav_v[1];
  pData[2] = u.nav_v[2];
  emlrtAssign(&u_y, m);
  emlrtSetFieldR2017b(y, 0, "nav_v", u_y, 19);
  v_y = nullptr;
  m = emlrtCreateNumericArray(1, (const void *)&i2, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  pData[0] = u.nav_euler[0];
  pData[1] = u.nav_euler[1];
  pData[2] = u.nav_euler[2];
  emlrtAssign(&v_y, m);
  emlrtSetFieldR2017b(y, 0, "nav_euler", v_y, 20);
  w_y = nullptr;
  m = emlrtCreateNumericArray(1, (const void *)&i3, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  pData[0] = u.nav_vel_body_water[0];
  pData[1] = u.nav_vel_body_water[1];
  pData[2] = u.nav_vel_body_water[2];
  emlrtAssign(&w_y, m);
  emlrtSetFieldR2017b(y, 0, "nav_vel_body_water", w_y, 21);
  x_y = nullptr;
  m = emlrtCreateLogicalScalar(u.nav_valid);
  emlrtAssign(&x_y, m);
  emlrtSetFieldR2017b(y, 0, "nav_valid", x_y, 22);
  y_y = nullptr;
  m = emlrtCreateLogicalScalar(u.nav_initialized);
  emlrtAssign(&y_y, m);
  emlrtSetFieldR2017b(y, 0, "nav_initialized", y_y, 23);
  ab_y = nullptr;
  m = emlrtCreateNumericMatrix(1, 1, mxUINT32_CLASS, mxREAL);
  *static_cast<uint32_T *>(emlrtMxGetData(m)) = u.nav_health_bits;
  emlrtAssign(&ab_y, m);
  emlrtSetFieldR2017b(y, 0, "nav_health_bits", ab_y, 24);
  bb_y = nullptr;
  m = emlrtCreateNumericMatrix(1, 1, mxUINT8_CLASS, mxREAL);
  *static_cast<uint8_T *>(emlrtMxGetData(m)) = u.availability_state;
  emlrtAssign(&bb_y, m);
  emlrtSetFieldR2017b(y, 0, "availability_state", bb_y, 25);
  cb_y = nullptr;
  m = emlrtCreateNumericMatrix(1, 1, mxUINT32_CLASS, mxREAL);
  *static_cast<uint32_T *>(emlrtMxGetData(m)) = u.availability_health_bits;
  emlrtAssign(&cb_y, m);
  emlrtSetFieldR2017b(y, 0, "availability_health_bits", cb_y, 26);
  db_y = nullptr;
  m = emlrtCreateDoubleScalar(u.fdir_residual);
  emlrtAssign(&db_y, m);
  emlrtSetFieldR2017b(y, 0, "fdir_residual", db_y, 27);
  eb_y = nullptr;
  m = emlrtCreateLogicalScalar(u.fdir_anomaly_latched);
  emlrtAssign(&eb_y, m);
  emlrtSetFieldR2017b(y, 0, "fdir_anomaly_latched", eb_y, 28);
  fb_y = nullptr;
  m = emlrtCreateNumericMatrix(1, 1, mxUINT32_CLASS, mxREAL);
  *static_cast<uint32_T *>(emlrtMxGetData(m)) = u.fdir_health_bits;
  emlrtAssign(&fb_y, m);
  emlrtSetFieldR2017b(y, 0, "fdir_health_bits", fb_y, 29);
  gb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.ctrl_delta_r);
  emlrtAssign(&gb_y, m);
  emlrtSetFieldR2017b(y, 0, "ctrl_delta_r", gb_y, 30);
  hb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.ctrl_delta_e);
  emlrtAssign(&hb_y, m);
  emlrtSetFieldR2017b(y, 0, "ctrl_delta_e", hb_y, 31);
  ib_y = nullptr;
  m = emlrtCreateDoubleScalar(u.ctrl_thrust);
  emlrtAssign(&ib_y, m);
  emlrtSetFieldR2017b(y, 0, "ctrl_thrust", ib_y, 32);
  jb_y = nullptr;
  m = emlrtCreateLogicalScalar(u.physical_io_written);
  emlrtAssign(&jb_y, m);
  emlrtSetFieldR2017b(y, 0, "physical_io_written", jb_y, 33);
  kb_y = nullptr;
  m = emlrtCreateLogicalScalar(u.actuator_isolated);
  emlrtAssign(&kb_y, m);
  emlrtSetFieldR2017b(y, 0, "actuator_isolated", kb_y, 34);
  lb_y = nullptr;
  m = emlrtCreateLogicalScalar(u.abort_requested);
  emlrtAssign(&lb_y, m);
  emlrtSetFieldR2017b(y, 0, "abort_requested", lb_y, 35);
  return y;
}

//
// Arguments    : const real_T u[4]
// Return Type  : const mxArray *
//
static const mxArray *emlrt_marshallOut(const real_T u[4])
{
  static const int32_T iv[2]{1, 4};
  const mxArray *m;
  const mxArray *y;
  real_T *pData;
  y = nullptr;
  m = emlrtCreateNumericArray(2, (const void *)&iv[0], mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  pData[0] = u[0];
  pData[1] = u[1];
  pData[2] = u[2];
  pData[3] = u[3];
  emlrtAssign(&y, m);
  return y;
}

//
// Arguments    : const struct1_T &u
// Return Type  : const mxArray *
//
static const mxArray *emlrt_marshallOut(const struct1_T &u)
{
  static const char_T *sv[32]{"Kp_psi",
                              "Kd_psi",
                              "Kp_x",
                              "Kp_roll",
                              "Kp_angle",
                              "Ki_angle",
                              "Kp_rate",
                              "Ki_rate",
                              "Kaw_pitch",
                              "Kd_rate",
                              "Kd_damp",
                              "delta_r_max",
                              "delta_e_max",
                              "thrust_max",
                              "thrust_min",
                              "thrust_trim",
                              "trim_speed_table",
                              "trim_elevator_table",
                              "elevator_sign",
                              "dt_controller",
                              "tau_rate",
                              "Muw",
                              "Muuds",
                              "lambda_muw_ff",
                              "muw_ff_u_min",
                              "muw_ff_u_lo",
                              "muw_ff_u_hi",
                              "muw_ff_clamp_deg",
                              "delta_e_trim",
                              "k_gamma_climb",
                              "de_climb_lim",
                              "slew_max_rad_s"};
  const mxArray *ab_y;
  const mxArray *b_y;
  const mxArray *bb_y;
  const mxArray *c_y;
  const mxArray *cb_y;
  const mxArray *d_y;
  const mxArray *db_y;
  const mxArray *e_y;
  const mxArray *eb_y;
  const mxArray *f_y;
  const mxArray *fb_y;
  const mxArray *g_y;
  const mxArray *h_y;
  const mxArray *i_y;
  const mxArray *j_y;
  const mxArray *k_y;
  const mxArray *l_y;
  const mxArray *m;
  const mxArray *m_y;
  const mxArray *n_y;
  const mxArray *o_y;
  const mxArray *p_y;
  const mxArray *q_y;
  const mxArray *r_y;
  const mxArray *s_y;
  const mxArray *t_y;
  const mxArray *u_y;
  const mxArray *v_y;
  const mxArray *w_y;
  const mxArray *x_y;
  const mxArray *y;
  const mxArray *y_y;
  y = nullptr;
  emlrtAssign(&y, emlrtCreateStructMatrix(1, 1, 32, (const char_T **)&sv[0]));
  b_y = nullptr;
  m = emlrtCreateDoubleScalar(u.Kp_psi);
  emlrtAssign(&b_y, m);
  emlrtSetFieldR2017b(y, 0, "Kp_psi", b_y, 0);
  c_y = nullptr;
  m = emlrtCreateDoubleScalar(u.Kd_psi);
  emlrtAssign(&c_y, m);
  emlrtSetFieldR2017b(y, 0, "Kd_psi", c_y, 1);
  d_y = nullptr;
  m = emlrtCreateDoubleScalar(u.Kp_x);
  emlrtAssign(&d_y, m);
  emlrtSetFieldR2017b(y, 0, "Kp_x", d_y, 2);
  e_y = nullptr;
  m = emlrtCreateDoubleScalar(u.Kp_roll);
  emlrtAssign(&e_y, m);
  emlrtSetFieldR2017b(y, 0, "Kp_roll", e_y, 3);
  f_y = nullptr;
  m = emlrtCreateDoubleScalar(u.Kp_angle);
  emlrtAssign(&f_y, m);
  emlrtSetFieldR2017b(y, 0, "Kp_angle", f_y, 4);
  g_y = nullptr;
  m = emlrtCreateDoubleScalar(u.Ki_angle);
  emlrtAssign(&g_y, m);
  emlrtSetFieldR2017b(y, 0, "Ki_angle", g_y, 5);
  h_y = nullptr;
  m = emlrtCreateDoubleScalar(u.Kp_rate);
  emlrtAssign(&h_y, m);
  emlrtSetFieldR2017b(y, 0, "Kp_rate", h_y, 6);
  i_y = nullptr;
  m = emlrtCreateDoubleScalar(u.Ki_rate);
  emlrtAssign(&i_y, m);
  emlrtSetFieldR2017b(y, 0, "Ki_rate", i_y, 7);
  j_y = nullptr;
  m = emlrtCreateDoubleScalar(u.Kaw_pitch);
  emlrtAssign(&j_y, m);
  emlrtSetFieldR2017b(y, 0, "Kaw_pitch", j_y, 8);
  k_y = nullptr;
  m = emlrtCreateDoubleScalar(u.Kd_rate);
  emlrtAssign(&k_y, m);
  emlrtSetFieldR2017b(y, 0, "Kd_rate", k_y, 9);
  l_y = nullptr;
  m = emlrtCreateDoubleScalar(u.Kd_damp);
  emlrtAssign(&l_y, m);
  emlrtSetFieldR2017b(y, 0, "Kd_damp", l_y, 10);
  m_y = nullptr;
  m = emlrtCreateDoubleScalar(u.delta_r_max);
  emlrtAssign(&m_y, m);
  emlrtSetFieldR2017b(y, 0, "delta_r_max", m_y, 11);
  n_y = nullptr;
  m = emlrtCreateDoubleScalar(u.delta_e_max);
  emlrtAssign(&n_y, m);
  emlrtSetFieldR2017b(y, 0, "delta_e_max", n_y, 12);
  o_y = nullptr;
  m = emlrtCreateDoubleScalar(u.thrust_max);
  emlrtAssign(&o_y, m);
  emlrtSetFieldR2017b(y, 0, "thrust_max", o_y, 13);
  p_y = nullptr;
  m = emlrtCreateDoubleScalar(u.thrust_min);
  emlrtAssign(&p_y, m);
  emlrtSetFieldR2017b(y, 0, "thrust_min", p_y, 14);
  q_y = nullptr;
  m = emlrtCreateDoubleScalar(u.thrust_trim);
  emlrtAssign(&q_y, m);
  emlrtSetFieldR2017b(y, 0, "thrust_trim", q_y, 15);
  emlrtSetFieldR2017b(y, 0, "trim_speed_table",
                      emlrt_marshallOut(u.trim_speed_table), 16);
  emlrtSetFieldR2017b(y, 0, "trim_elevator_table",
                      emlrt_marshallOut(u.trim_elevator_table), 17);
  r_y = nullptr;
  m = emlrtCreateDoubleScalar(u.elevator_sign);
  emlrtAssign(&r_y, m);
  emlrtSetFieldR2017b(y, 0, "elevator_sign", r_y, 18);
  s_y = nullptr;
  m = emlrtCreateDoubleScalar(u.dt_controller);
  emlrtAssign(&s_y, m);
  emlrtSetFieldR2017b(y, 0, "dt_controller", s_y, 19);
  t_y = nullptr;
  m = emlrtCreateDoubleScalar(u.tau_rate);
  emlrtAssign(&t_y, m);
  emlrtSetFieldR2017b(y, 0, "tau_rate", t_y, 20);
  u_y = nullptr;
  m = emlrtCreateDoubleScalar(u.Muw);
  emlrtAssign(&u_y, m);
  emlrtSetFieldR2017b(y, 0, "Muw", u_y, 21);
  v_y = nullptr;
  m = emlrtCreateDoubleScalar(u.Muuds);
  emlrtAssign(&v_y, m);
  emlrtSetFieldR2017b(y, 0, "Muuds", v_y, 22);
  w_y = nullptr;
  m = emlrtCreateDoubleScalar(u.lambda_muw_ff);
  emlrtAssign(&w_y, m);
  emlrtSetFieldR2017b(y, 0, "lambda_muw_ff", w_y, 23);
  x_y = nullptr;
  m = emlrtCreateDoubleScalar(u.muw_ff_u_min);
  emlrtAssign(&x_y, m);
  emlrtSetFieldR2017b(y, 0, "muw_ff_u_min", x_y, 24);
  y_y = nullptr;
  m = emlrtCreateDoubleScalar(u.muw_ff_u_lo);
  emlrtAssign(&y_y, m);
  emlrtSetFieldR2017b(y, 0, "muw_ff_u_lo", y_y, 25);
  ab_y = nullptr;
  m = emlrtCreateDoubleScalar(u.muw_ff_u_hi);
  emlrtAssign(&ab_y, m);
  emlrtSetFieldR2017b(y, 0, "muw_ff_u_hi", ab_y, 26);
  bb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.muw_ff_clamp_deg);
  emlrtAssign(&bb_y, m);
  emlrtSetFieldR2017b(y, 0, "muw_ff_clamp_deg", bb_y, 27);
  cb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.delta_e_trim);
  emlrtAssign(&cb_y, m);
  emlrtSetFieldR2017b(y, 0, "delta_e_trim", cb_y, 28);
  db_y = nullptr;
  m = emlrtCreateDoubleScalar(u.k_gamma_climb);
  emlrtAssign(&db_y, m);
  emlrtSetFieldR2017b(y, 0, "k_gamma_climb", db_y, 29);
  eb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.de_climb_lim);
  emlrtAssign(&eb_y, m);
  emlrtSetFieldR2017b(y, 0, "de_climb_lim", eb_y, 30);
  fb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.slew_max_rad_s);
  emlrtAssign(&fb_y, m);
  emlrtSetFieldR2017b(y, 0, "slew_max_rad_s", fb_y, 31);
  return y;
}

//
// Arguments    : const struct9_T &u
// Return Type  : const mxArray *
//
static const mxArray *emlrt_marshallOut(const struct9_T &u)
{
  static const char_T *sv[19]{"controller",
                              "guidance",
                              "navigation",
                              "availability",
                              "fdir",
                              "tick_count",
                              "have_tick",
                              "last_tick_seq",
                              "last_t",
                              "progress_index",
                              "yaw",
                              "pitch",
                              "u",
                              "r_ff",
                              "pitch_dot",
                              "guidance_ready",
                              "arm_state",
                              "healthy_streak",
                              "fault_bits_latched"};
  static const char_T *sv2[17]{"initialized", "s_prog",        "yaw_cont",
                               "pitch_f",     "z_e_f",         "z_e_i",
                               "zd_e_f",      "eg_f",          "alpha_hat",
                               "kappa_f",     "chi_f",         "yaw_out",
                               "pitch_out",   "have_yaw_cont", "have_pitch_f",
                               "have_chi_f",  "have_yaw_out"};
  static const char_T *sv1[7]{"prev_delta_r", "prev_delta_e", "int_angle",
                              "int_rate",     "rate_filt",    "prev_e_rate",
                              "initialized"};
  static const char_T *sv3[7]{
      "initialized",      "persist_count", "anomaly_latched", "alarm_time_s",
      "alarm_time_valid", "last_seq",      "have_seq"};
  const mxArray *ab_y;
  const mxArray *b_y;
  const mxArray *bb_y;
  const mxArray *c_y;
  const mxArray *cb_y;
  const mxArray *d_y;
  const mxArray *db_y;
  const mxArray *e_y;
  const mxArray *eb_y;
  const mxArray *f_y;
  const mxArray *fb_y;
  const mxArray *g_y;
  const mxArray *gb_y;
  const mxArray *h_y;
  const mxArray *hb_y;
  const mxArray *i_y;
  const mxArray *ib_y;
  const mxArray *j_y;
  const mxArray *jb_y;
  const mxArray *k_y;
  const mxArray *kb_y;
  const mxArray *l_y;
  const mxArray *lb_y;
  const mxArray *m;
  const mxArray *m_y;
  const mxArray *mb_y;
  const mxArray *n_y;
  const mxArray *nb_y;
  const mxArray *o_y;
  const mxArray *ob_y;
  const mxArray *p_y;
  const mxArray *pb_y;
  const mxArray *q_y;
  const mxArray *qb_y;
  const mxArray *r_y;
  const mxArray *rb_y;
  const mxArray *s_y;
  const mxArray *sb_y;
  const mxArray *t_y;
  const mxArray *tb_y;
  const mxArray *u_y;
  const mxArray *ub_y;
  const mxArray *v_y;
  const mxArray *vb_y;
  const mxArray *w_y;
  const mxArray *wb_y;
  const mxArray *x_y;
  const mxArray *xb_y;
  const mxArray *y;
  const mxArray *y_y;
  y = nullptr;
  emlrtAssign(&y, emlrtCreateStructMatrix(1, 1, 19, (const char_T **)&sv[0]));
  b_y = nullptr;
  emlrtAssign(&b_y, emlrtCreateStructMatrix(1, 1, 7, (const char_T **)&sv1[0]));
  c_y = nullptr;
  m = emlrtCreateDoubleScalar(u.controller.prev_delta_r);
  emlrtAssign(&c_y, m);
  emlrtSetFieldR2017b(b_y, 0, "prev_delta_r", c_y, 0);
  d_y = nullptr;
  m = emlrtCreateDoubleScalar(u.controller.prev_delta_e);
  emlrtAssign(&d_y, m);
  emlrtSetFieldR2017b(b_y, 0, "prev_delta_e", d_y, 1);
  e_y = nullptr;
  m = emlrtCreateDoubleScalar(u.controller.int_angle);
  emlrtAssign(&e_y, m);
  emlrtSetFieldR2017b(b_y, 0, "int_angle", e_y, 2);
  f_y = nullptr;
  m = emlrtCreateDoubleScalar(u.controller.int_rate);
  emlrtAssign(&f_y, m);
  emlrtSetFieldR2017b(b_y, 0, "int_rate", f_y, 3);
  g_y = nullptr;
  m = emlrtCreateDoubleScalar(u.controller.rate_filt);
  emlrtAssign(&g_y, m);
  emlrtSetFieldR2017b(b_y, 0, "rate_filt", g_y, 4);
  h_y = nullptr;
  m = emlrtCreateDoubleScalar(u.controller.prev_e_rate);
  emlrtAssign(&h_y, m);
  emlrtSetFieldR2017b(b_y, 0, "prev_e_rate", h_y, 5);
  i_y = nullptr;
  m = emlrtCreateDoubleScalar(u.controller.initialized);
  emlrtAssign(&i_y, m);
  emlrtSetFieldR2017b(b_y, 0, "initialized", i_y, 6);
  emlrtSetFieldR2017b(y, 0, "controller", b_y, 0);
  j_y = nullptr;
  emlrtAssign(&j_y,
              emlrtCreateStructMatrix(1, 1, 17, (const char_T **)&sv2[0]));
  k_y = nullptr;
  m = emlrtCreateLogicalScalar(u.guidance.initialized);
  emlrtAssign(&k_y, m);
  emlrtSetFieldR2017b(j_y, 0, "initialized", k_y, 0);
  l_y = nullptr;
  m = emlrtCreateDoubleScalar(u.guidance.s_prog);
  emlrtAssign(&l_y, m);
  emlrtSetFieldR2017b(j_y, 0, "s_prog", l_y, 1);
  m_y = nullptr;
  m = emlrtCreateDoubleScalar(u.guidance.yaw_cont);
  emlrtAssign(&m_y, m);
  emlrtSetFieldR2017b(j_y, 0, "yaw_cont", m_y, 2);
  n_y = nullptr;
  m = emlrtCreateDoubleScalar(u.guidance.pitch_f);
  emlrtAssign(&n_y, m);
  emlrtSetFieldR2017b(j_y, 0, "pitch_f", n_y, 3);
  o_y = nullptr;
  m = emlrtCreateDoubleScalar(u.guidance.z_e_f);
  emlrtAssign(&o_y, m);
  emlrtSetFieldR2017b(j_y, 0, "z_e_f", o_y, 4);
  p_y = nullptr;
  m = emlrtCreateDoubleScalar(u.guidance.z_e_i);
  emlrtAssign(&p_y, m);
  emlrtSetFieldR2017b(j_y, 0, "z_e_i", p_y, 5);
  q_y = nullptr;
  m = emlrtCreateDoubleScalar(u.guidance.zd_e_f);
  emlrtAssign(&q_y, m);
  emlrtSetFieldR2017b(j_y, 0, "zd_e_f", q_y, 6);
  r_y = nullptr;
  m = emlrtCreateDoubleScalar(u.guidance.eg_f);
  emlrtAssign(&r_y, m);
  emlrtSetFieldR2017b(j_y, 0, "eg_f", r_y, 7);
  s_y = nullptr;
  m = emlrtCreateDoubleScalar(u.guidance.alpha_hat);
  emlrtAssign(&s_y, m);
  emlrtSetFieldR2017b(j_y, 0, "alpha_hat", s_y, 8);
  t_y = nullptr;
  m = emlrtCreateDoubleScalar(u.guidance.kappa_f);
  emlrtAssign(&t_y, m);
  emlrtSetFieldR2017b(j_y, 0, "kappa_f", t_y, 9);
  u_y = nullptr;
  m = emlrtCreateDoubleScalar(u.guidance.chi_f);
  emlrtAssign(&u_y, m);
  emlrtSetFieldR2017b(j_y, 0, "chi_f", u_y, 10);
  v_y = nullptr;
  m = emlrtCreateDoubleScalar(u.guidance.yaw_out);
  emlrtAssign(&v_y, m);
  emlrtSetFieldR2017b(j_y, 0, "yaw_out", v_y, 11);
  w_y = nullptr;
  m = emlrtCreateDoubleScalar(u.guidance.pitch_out);
  emlrtAssign(&w_y, m);
  emlrtSetFieldR2017b(j_y, 0, "pitch_out", w_y, 12);
  x_y = nullptr;
  m = emlrtCreateLogicalScalar(u.guidance.have_yaw_cont);
  emlrtAssign(&x_y, m);
  emlrtSetFieldR2017b(j_y, 0, "have_yaw_cont", x_y, 13);
  y_y = nullptr;
  m = emlrtCreateLogicalScalar(u.guidance.have_pitch_f);
  emlrtAssign(&y_y, m);
  emlrtSetFieldR2017b(j_y, 0, "have_pitch_f", y_y, 14);
  ab_y = nullptr;
  m = emlrtCreateLogicalScalar(u.guidance.have_chi_f);
  emlrtAssign(&ab_y, m);
  emlrtSetFieldR2017b(j_y, 0, "have_chi_f", ab_y, 15);
  bb_y = nullptr;
  m = emlrtCreateLogicalScalar(u.guidance.have_yaw_out);
  emlrtAssign(&bb_y, m);
  emlrtSetFieldR2017b(j_y, 0, "have_yaw_out", bb_y, 16);
  emlrtSetFieldR2017b(y, 0, "guidance", j_y, 1);
  emlrtSetFieldR2017b(y, 0, "navigation", emlrt_marshallOut(u.navigation), 2);
  emlrtSetFieldR2017b(y, 0, "availability", emlrt_marshallOut(u.availability),
                      3);
  cb_y = nullptr;
  emlrtAssign(&cb_y,
              emlrtCreateStructMatrix(1, 1, 7, (const char_T **)&sv3[0]));
  db_y = nullptr;
  m = emlrtCreateLogicalScalar(u.fdir.initialized);
  emlrtAssign(&db_y, m);
  emlrtSetFieldR2017b(cb_y, 0, "initialized", db_y, 0);
  eb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.fdir.persist_count);
  emlrtAssign(&eb_y, m);
  emlrtSetFieldR2017b(cb_y, 0, "persist_count", eb_y, 1);
  fb_y = nullptr;
  m = emlrtCreateLogicalScalar(u.fdir.anomaly_latched);
  emlrtAssign(&fb_y, m);
  emlrtSetFieldR2017b(cb_y, 0, "anomaly_latched", fb_y, 2);
  gb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.fdir.alarm_time_s);
  emlrtAssign(&gb_y, m);
  emlrtSetFieldR2017b(cb_y, 0, "alarm_time_s", gb_y, 3);
  hb_y = nullptr;
  m = emlrtCreateLogicalScalar(u.fdir.alarm_time_valid);
  emlrtAssign(&hb_y, m);
  emlrtSetFieldR2017b(cb_y, 0, "alarm_time_valid", hb_y, 4);
  ib_y = nullptr;
  m = emlrtCreateNumericMatrix(1, 1, mxUINT32_CLASS, mxREAL);
  *static_cast<uint32_T *>(emlrtMxGetData(m)) = u.fdir.last_seq;
  emlrtAssign(&ib_y, m);
  emlrtSetFieldR2017b(cb_y, 0, "last_seq", ib_y, 5);
  jb_y = nullptr;
  m = emlrtCreateLogicalScalar(u.fdir.have_seq);
  emlrtAssign(&jb_y, m);
  emlrtSetFieldR2017b(cb_y, 0, "have_seq", jb_y, 6);
  emlrtSetFieldR2017b(y, 0, "fdir", cb_y, 4);
  kb_y = nullptr;
  m = emlrtCreateNumericMatrix(1, 1, mxUINT32_CLASS, mxREAL);
  *static_cast<uint32_T *>(emlrtMxGetData(m)) = u.tick_count;
  emlrtAssign(&kb_y, m);
  emlrtSetFieldR2017b(y, 0, "tick_count", kb_y, 5);
  lb_y = nullptr;
  m = emlrtCreateLogicalScalar(u.have_tick);
  emlrtAssign(&lb_y, m);
  emlrtSetFieldR2017b(y, 0, "have_tick", lb_y, 6);
  mb_y = nullptr;
  m = emlrtCreateNumericMatrix(1, 1, mxUINT32_CLASS, mxREAL);
  *static_cast<uint32_T *>(emlrtMxGetData(m)) = u.last_tick_seq;
  emlrtAssign(&mb_y, m);
  emlrtSetFieldR2017b(y, 0, "last_tick_seq", mb_y, 7);
  nb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.last_t);
  emlrtAssign(&nb_y, m);
  emlrtSetFieldR2017b(y, 0, "last_t", nb_y, 8);
  ob_y = nullptr;
  m = emlrtCreateDoubleScalar(u.progress_index);
  emlrtAssign(&ob_y, m);
  emlrtSetFieldR2017b(y, 0, "progress_index", ob_y, 9);
  pb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.yaw);
  emlrtAssign(&pb_y, m);
  emlrtSetFieldR2017b(y, 0, "yaw", pb_y, 10);
  qb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.pitch);
  emlrtAssign(&qb_y, m);
  emlrtSetFieldR2017b(y, 0, "pitch", qb_y, 11);
  rb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.u);
  emlrtAssign(&rb_y, m);
  emlrtSetFieldR2017b(y, 0, "u", rb_y, 12);
  sb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.r_ff);
  emlrtAssign(&sb_y, m);
  emlrtSetFieldR2017b(y, 0, "r_ff", sb_y, 13);
  tb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.pitch_dot);
  emlrtAssign(&tb_y, m);
  emlrtSetFieldR2017b(y, 0, "pitch_dot", tb_y, 14);
  ub_y = nullptr;
  m = emlrtCreateLogicalScalar(u.guidance_ready);
  emlrtAssign(&ub_y, m);
  emlrtSetFieldR2017b(y, 0, "guidance_ready", ub_y, 15);
  vb_y = nullptr;
  m = emlrtCreateNumericMatrix(1, 1, mxUINT8_CLASS, mxREAL);
  *static_cast<uint8_T *>(emlrtMxGetData(m)) = u.arm_state;
  emlrtAssign(&vb_y, m);
  emlrtSetFieldR2017b(y, 0, "arm_state", vb_y, 16);
  wb_y = nullptr;
  m = emlrtCreateNumericMatrix(1, 1, mxUINT32_CLASS, mxREAL);
  *static_cast<uint32_T *>(emlrtMxGetData(m)) = u.healthy_streak;
  emlrtAssign(&wb_y, m);
  emlrtSetFieldR2017b(y, 0, "healthy_streak", wb_y, 17);
  xb_y = nullptr;
  m = emlrtCreateNumericMatrix(1, 1, mxUINT32_CLASS, mxREAL);
  *static_cast<uint32_T *>(emlrtMxGetData(m)) = u.fault_bits_latched;
  emlrtAssign(&xb_y, m);
  emlrtSetFieldR2017b(y, 0, "fault_bits_latched", xb_y, 18);
  return y;
}

//
// Arguments    : const struct6_T &u
// Return Type  : const mxArray *
//
static const mxArray *emlrt_marshallOut(const struct6_T &u)
{
  static const int32_T i{3};
  static const int32_T i1{3};
  static const int32_T i2{3};
  static const int32_T i3{3};
  static const int32_T i4{3};
  static const int32_T i5{3};
  static const int32_T i6{3};
  static const int32_T i7{3};
  static const int32_T i8{3};
  static const char_T *sv[33]{
      "g_ned",    "sigma_p",   "sigma_a",     "sigma_g",     "sigma_bg",
      "sigma_ba", "sigma_c",   "R_depth",     "R_heading",   "R_ins",
      "R_dvl",    "R_usbl",    "lat_depth",   "lat_heading", "lat_ins",
      "lat_dvl",  "lat_usbl",  "P0_p",        "P0_p_abs",    "P0_v",
      "P0_th",    "P0_bg",     "P0_ba",       "P0_c",        "q_min_frac",
      "q_floor",  "nis_scale", "dt_prop_max", "dt_prop_sub", "n_sub_max",
      "tol_time", "tol_pair",  "config_valid"};
  const mxArray *ab_y;
  const mxArray *b_y;
  const mxArray *bb_y;
  const mxArray *c_y;
  const mxArray *cb_y;
  const mxArray *d_y;
  const mxArray *db_y;
  const mxArray *e_y;
  const mxArray *eb_y;
  const mxArray *f_y;
  const mxArray *fb_y;
  const mxArray *g_y;
  const mxArray *gb_y;
  const mxArray *h_y;
  const mxArray *hb_y;
  const mxArray *i_y;
  const mxArray *ib_y;
  const mxArray *j_y;
  const mxArray *k_y;
  const mxArray *l_y;
  const mxArray *m;
  const mxArray *m_y;
  const mxArray *n_y;
  const mxArray *o_y;
  const mxArray *p_y;
  const mxArray *q_y;
  const mxArray *r_y;
  const mxArray *s_y;
  const mxArray *t_y;
  const mxArray *u_y;
  const mxArray *v_y;
  const mxArray *w_y;
  const mxArray *x_y;
  const mxArray *y;
  const mxArray *y_y;
  real_T *pData;
  y = nullptr;
  emlrtAssign(&y, emlrtCreateStructMatrix(1, 1, 33, (const char_T **)&sv[0]));
  b_y = nullptr;
  m = emlrtCreateDoubleScalar(u.g_ned);
  emlrtAssign(&b_y, m);
  emlrtSetFieldR2017b(y, 0, "g_ned", b_y, 0);
  c_y = nullptr;
  m = emlrtCreateDoubleScalar(u.sigma_p);
  emlrtAssign(&c_y, m);
  emlrtSetFieldR2017b(y, 0, "sigma_p", c_y, 1);
  d_y = nullptr;
  m = emlrtCreateDoubleScalar(u.sigma_a);
  emlrtAssign(&d_y, m);
  emlrtSetFieldR2017b(y, 0, "sigma_a", d_y, 2);
  e_y = nullptr;
  m = emlrtCreateDoubleScalar(u.sigma_g);
  emlrtAssign(&e_y, m);
  emlrtSetFieldR2017b(y, 0, "sigma_g", e_y, 3);
  f_y = nullptr;
  m = emlrtCreateDoubleScalar(u.sigma_bg);
  emlrtAssign(&f_y, m);
  emlrtSetFieldR2017b(y, 0, "sigma_bg", f_y, 4);
  g_y = nullptr;
  m = emlrtCreateDoubleScalar(u.sigma_ba);
  emlrtAssign(&g_y, m);
  emlrtSetFieldR2017b(y, 0, "sigma_ba", g_y, 5);
  h_y = nullptr;
  m = emlrtCreateDoubleScalar(u.sigma_c);
  emlrtAssign(&h_y, m);
  emlrtSetFieldR2017b(y, 0, "sigma_c", h_y, 6);
  i_y = nullptr;
  m = emlrtCreateDoubleScalar(u.R_depth);
  emlrtAssign(&i_y, m);
  emlrtSetFieldR2017b(y, 0, "R_depth", i_y, 7);
  j_y = nullptr;
  m = emlrtCreateDoubleScalar(u.R_heading);
  emlrtAssign(&j_y, m);
  emlrtSetFieldR2017b(y, 0, "R_heading", j_y, 8);
  k_y = nullptr;
  m = emlrtCreateNumericArray(1, (const void *)&i, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  pData[0] = u.R_ins[0];
  pData[1] = u.R_ins[1];
  pData[2] = u.R_ins[2];
  emlrtAssign(&k_y, m);
  emlrtSetFieldR2017b(y, 0, "R_ins", k_y, 9);
  l_y = nullptr;
  m = emlrtCreateNumericArray(1, (const void *)&i1, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  pData[0] = u.R_dvl[0];
  pData[1] = u.R_dvl[1];
  pData[2] = u.R_dvl[2];
  emlrtAssign(&l_y, m);
  emlrtSetFieldR2017b(y, 0, "R_dvl", l_y, 10);
  m_y = nullptr;
  m = emlrtCreateNumericArray(1, (const void *)&i2, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  pData[0] = u.R_usbl[0];
  pData[1] = u.R_usbl[1];
  pData[2] = u.R_usbl[2];
  emlrtAssign(&m_y, m);
  emlrtSetFieldR2017b(y, 0, "R_usbl", m_y, 11);
  n_y = nullptr;
  m = emlrtCreateDoubleScalar(u.lat_depth);
  emlrtAssign(&n_y, m);
  emlrtSetFieldR2017b(y, 0, "lat_depth", n_y, 12);
  o_y = nullptr;
  m = emlrtCreateDoubleScalar(u.lat_heading);
  emlrtAssign(&o_y, m);
  emlrtSetFieldR2017b(y, 0, "lat_heading", o_y, 13);
  p_y = nullptr;
  m = emlrtCreateDoubleScalar(u.lat_ins);
  emlrtAssign(&p_y, m);
  emlrtSetFieldR2017b(y, 0, "lat_ins", p_y, 14);
  q_y = nullptr;
  m = emlrtCreateDoubleScalar(u.lat_dvl);
  emlrtAssign(&q_y, m);
  emlrtSetFieldR2017b(y, 0, "lat_dvl", q_y, 15);
  r_y = nullptr;
  m = emlrtCreateDoubleScalar(u.lat_usbl);
  emlrtAssign(&r_y, m);
  emlrtSetFieldR2017b(y, 0, "lat_usbl", r_y, 16);
  s_y = nullptr;
  m = emlrtCreateNumericArray(1, (const void *)&i3, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  pData[0] = u.P0_p[0];
  pData[1] = u.P0_p[1];
  pData[2] = u.P0_p[2];
  emlrtAssign(&s_y, m);
  emlrtSetFieldR2017b(y, 0, "P0_p", s_y, 17);
  t_y = nullptr;
  m = emlrtCreateDoubleScalar(u.P0_p_abs);
  emlrtAssign(&t_y, m);
  emlrtSetFieldR2017b(y, 0, "P0_p_abs", t_y, 18);
  u_y = nullptr;
  m = emlrtCreateNumericArray(1, (const void *)&i4, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  pData[0] = u.P0_v[0];
  pData[1] = u.P0_v[1];
  pData[2] = u.P0_v[2];
  emlrtAssign(&u_y, m);
  emlrtSetFieldR2017b(y, 0, "P0_v", u_y, 19);
  v_y = nullptr;
  m = emlrtCreateNumericArray(1, (const void *)&i5, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  pData[0] = u.P0_th[0];
  pData[1] = u.P0_th[1];
  pData[2] = u.P0_th[2];
  emlrtAssign(&v_y, m);
  emlrtSetFieldR2017b(y, 0, "P0_th", v_y, 20);
  w_y = nullptr;
  m = emlrtCreateNumericArray(1, (const void *)&i6, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  pData[0] = u.P0_bg[0];
  pData[1] = u.P0_bg[1];
  pData[2] = u.P0_bg[2];
  emlrtAssign(&w_y, m);
  emlrtSetFieldR2017b(y, 0, "P0_bg", w_y, 21);
  x_y = nullptr;
  m = emlrtCreateNumericArray(1, (const void *)&i7, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  pData[0] = u.P0_ba[0];
  pData[1] = u.P0_ba[1];
  pData[2] = u.P0_ba[2];
  emlrtAssign(&x_y, m);
  emlrtSetFieldR2017b(y, 0, "P0_ba", x_y, 22);
  y_y = nullptr;
  m = emlrtCreateNumericArray(1, (const void *)&i8, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  pData[0] = u.P0_c[0];
  pData[1] = u.P0_c[1];
  pData[2] = u.P0_c[2];
  emlrtAssign(&y_y, m);
  emlrtSetFieldR2017b(y, 0, "P0_c", y_y, 23);
  ab_y = nullptr;
  m = emlrtCreateDoubleScalar(u.q_min_frac);
  emlrtAssign(&ab_y, m);
  emlrtSetFieldR2017b(y, 0, "q_min_frac", ab_y, 24);
  bb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.q_floor);
  emlrtAssign(&bb_y, m);
  emlrtSetFieldR2017b(y, 0, "q_floor", bb_y, 25);
  cb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.nis_scale);
  emlrtAssign(&cb_y, m);
  emlrtSetFieldR2017b(y, 0, "nis_scale", cb_y, 26);
  db_y = nullptr;
  m = emlrtCreateDoubleScalar(u.dt_prop_max);
  emlrtAssign(&db_y, m);
  emlrtSetFieldR2017b(y, 0, "dt_prop_max", db_y, 27);
  eb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.dt_prop_sub);
  emlrtAssign(&eb_y, m);
  emlrtSetFieldR2017b(y, 0, "dt_prop_sub", eb_y, 28);
  fb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.n_sub_max);
  emlrtAssign(&fb_y, m);
  emlrtSetFieldR2017b(y, 0, "n_sub_max", fb_y, 29);
  gb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.tol_time);
  emlrtAssign(&gb_y, m);
  emlrtSetFieldR2017b(y, 0, "tol_time", gb_y, 30);
  hb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.tol_pair);
  emlrtAssign(&hb_y, m);
  emlrtSetFieldR2017b(y, 0, "tol_pair", hb_y, 31);
  ib_y = nullptr;
  m = emlrtCreateLogicalScalar(u.config_valid);
  emlrtAssign(&ib_y, m);
  emlrtSetFieldR2017b(y, 0, "config_valid", ib_y, 32);
  return y;
}

//
// Arguments    : const struct5_T &u
// Return Type  : const mxArray *
//
static const mxArray *emlrt_marshallOut(const struct5_T &u)
{
  static const int32_T i{7};
  static const int32_T i1{7};
  static const int32_T i2{7};
  static const int32_T i3{7};
  static const char_T *sv1[20]{"MAX_PATH_POINTS",
                               "lookahead_distance",
                               "desired_speed",
                               "pitch_ref_max",
                               "pitch_ref_rate_max",
                               "dt_guidance",
                               "dt_controller",
                               "K_zdot",
                               "K_gamma",
                               "enable_alpha_hat",
                               "k_beta",
                               "closed_eps",
                               "near_end_margin",
                               "mono_back_max",
                               "s_back_tol",
                               "yaw_slew_max_rad_s",
                               "r_ff_max_rad_s",
                               "pitch_corr_max",
                               "z_e_i_max",
                               "alpha_hat_max"};
  static const char_T *sv2[13]{
      "T_degrade",   "T_lost",    "T_reacq",     "T_clear", "T_settle",
      "tol_time",    "k_fresh",   "tau_floor",   "present", "period",
      "stale_limit", "tau_fresh", "config_valid"};
  static const char_T *sv[9]{
      "controller",  "guidance",    "navigation",       "availability",
      "fdir",        "safe_thrust", "guidance_divider", "arm_min_healthy_ticks",
      "config_valid"};
  static const char_T *sv3[9]{"G_nom",     "thr_B2",     "eps_dr_rad",
                              "u_floor",   "t_warmup_s", "Np",
                              "persist_s", "dt",         "config_valid"};
  const mxArray *ab_y;
  const mxArray *b_y;
  const mxArray *bb_y;
  const mxArray *c_y;
  const mxArray *cb_y;
  const mxArray *d_y;
  const mxArray *db_y;
  const mxArray *e_y;
  const mxArray *eb_y;
  const mxArray *f_y;
  const mxArray *fb_y;
  const mxArray *g_y;
  const mxArray *gb_y;
  const mxArray *h_y;
  const mxArray *hb_y;
  const mxArray *i_y;
  const mxArray *ib_y;
  const mxArray *j_y;
  const mxArray *jb_y;
  const mxArray *k_y;
  const mxArray *kb_y;
  const mxArray *l_y;
  const mxArray *lb_y;
  const mxArray *m;
  const mxArray *m_y;
  const mxArray *mb_y;
  const mxArray *n_y;
  const mxArray *nb_y;
  const mxArray *o_y;
  const mxArray *ob_y;
  const mxArray *p_y;
  const mxArray *pb_y;
  const mxArray *q_y;
  const mxArray *qb_y;
  const mxArray *r_y;
  const mxArray *rb_y;
  const mxArray *s_y;
  const mxArray *sb_y;
  const mxArray *t_y;
  const mxArray *tb_y;
  const mxArray *u_y;
  const mxArray *ub_y;
  const mxArray *v_y;
  const mxArray *vb_y;
  const mxArray *w_y;
  const mxArray *wb_y;
  const mxArray *x_y;
  const mxArray *xb_y;
  const mxArray *y;
  const mxArray *y_y;
  const mxArray *yb_y;
  real_T *pData;
  y = nullptr;
  emlrtAssign(&y, emlrtCreateStructMatrix(1, 1, 9, (const char_T **)&sv[0]));
  emlrtSetFieldR2017b(y, 0, "controller", emlrt_marshallOut(u.controller), 0);
  b_y = nullptr;
  emlrtAssign(&b_y,
              emlrtCreateStructMatrix(1, 1, 20, (const char_T **)&sv1[0]));
  c_y = nullptr;
  m = emlrtCreateDoubleScalar(u.guidance.MAX_PATH_POINTS);
  emlrtAssign(&c_y, m);
  emlrtSetFieldR2017b(b_y, 0, "MAX_PATH_POINTS", c_y, 0);
  d_y = nullptr;
  m = emlrtCreateDoubleScalar(u.guidance.lookahead_distance);
  emlrtAssign(&d_y, m);
  emlrtSetFieldR2017b(b_y, 0, "lookahead_distance", d_y, 1);
  e_y = nullptr;
  m = emlrtCreateDoubleScalar(u.guidance.desired_speed);
  emlrtAssign(&e_y, m);
  emlrtSetFieldR2017b(b_y, 0, "desired_speed", e_y, 2);
  f_y = nullptr;
  m = emlrtCreateDoubleScalar(u.guidance.pitch_ref_max);
  emlrtAssign(&f_y, m);
  emlrtSetFieldR2017b(b_y, 0, "pitch_ref_max", f_y, 3);
  g_y = nullptr;
  m = emlrtCreateDoubleScalar(u.guidance.pitch_ref_rate_max);
  emlrtAssign(&g_y, m);
  emlrtSetFieldR2017b(b_y, 0, "pitch_ref_rate_max", g_y, 4);
  h_y = nullptr;
  m = emlrtCreateDoubleScalar(u.guidance.dt_guidance);
  emlrtAssign(&h_y, m);
  emlrtSetFieldR2017b(b_y, 0, "dt_guidance", h_y, 5);
  i_y = nullptr;
  m = emlrtCreateDoubleScalar(u.guidance.dt_controller);
  emlrtAssign(&i_y, m);
  emlrtSetFieldR2017b(b_y, 0, "dt_controller", i_y, 6);
  j_y = nullptr;
  m = emlrtCreateDoubleScalar(u.guidance.K_zdot);
  emlrtAssign(&j_y, m);
  emlrtSetFieldR2017b(b_y, 0, "K_zdot", j_y, 7);
  k_y = nullptr;
  m = emlrtCreateDoubleScalar(u.guidance.K_gamma);
  emlrtAssign(&k_y, m);
  emlrtSetFieldR2017b(b_y, 0, "K_gamma", k_y, 8);
  l_y = nullptr;
  m = emlrtCreateLogicalScalar(u.guidance.enable_alpha_hat);
  emlrtAssign(&l_y, m);
  emlrtSetFieldR2017b(b_y, 0, "enable_alpha_hat", l_y, 9);
  m_y = nullptr;
  m = emlrtCreateDoubleScalar(u.guidance.k_beta);
  emlrtAssign(&m_y, m);
  emlrtSetFieldR2017b(b_y, 0, "k_beta", m_y, 10);
  n_y = nullptr;
  m = emlrtCreateDoubleScalar(u.guidance.closed_eps);
  emlrtAssign(&n_y, m);
  emlrtSetFieldR2017b(b_y, 0, "closed_eps", n_y, 11);
  o_y = nullptr;
  m = emlrtCreateDoubleScalar(u.guidance.near_end_margin);
  emlrtAssign(&o_y, m);
  emlrtSetFieldR2017b(b_y, 0, "near_end_margin", o_y, 12);
  p_y = nullptr;
  m = emlrtCreateDoubleScalar(u.guidance.mono_back_max);
  emlrtAssign(&p_y, m);
  emlrtSetFieldR2017b(b_y, 0, "mono_back_max", p_y, 13);
  q_y = nullptr;
  m = emlrtCreateDoubleScalar(u.guidance.s_back_tol);
  emlrtAssign(&q_y, m);
  emlrtSetFieldR2017b(b_y, 0, "s_back_tol", q_y, 14);
  r_y = nullptr;
  m = emlrtCreateDoubleScalar(u.guidance.yaw_slew_max_rad_s);
  emlrtAssign(&r_y, m);
  emlrtSetFieldR2017b(b_y, 0, "yaw_slew_max_rad_s", r_y, 15);
  s_y = nullptr;
  m = emlrtCreateDoubleScalar(u.guidance.r_ff_max_rad_s);
  emlrtAssign(&s_y, m);
  emlrtSetFieldR2017b(b_y, 0, "r_ff_max_rad_s", s_y, 16);
  t_y = nullptr;
  m = emlrtCreateDoubleScalar(u.guidance.pitch_corr_max);
  emlrtAssign(&t_y, m);
  emlrtSetFieldR2017b(b_y, 0, "pitch_corr_max", t_y, 17);
  u_y = nullptr;
  m = emlrtCreateDoubleScalar(u.guidance.z_e_i_max);
  emlrtAssign(&u_y, m);
  emlrtSetFieldR2017b(b_y, 0, "z_e_i_max", u_y, 18);
  v_y = nullptr;
  m = emlrtCreateDoubleScalar(u.guidance.alpha_hat_max);
  emlrtAssign(&v_y, m);
  emlrtSetFieldR2017b(b_y, 0, "alpha_hat_max", v_y, 19);
  emlrtSetFieldR2017b(y, 0, "guidance", b_y, 1);
  emlrtSetFieldR2017b(y, 0, "navigation", emlrt_marshallOut(u.navigation), 2);
  w_y = nullptr;
  emlrtAssign(&w_y,
              emlrtCreateStructMatrix(1, 1, 13, (const char_T **)&sv2[0]));
  x_y = nullptr;
  m = emlrtCreateDoubleScalar(u.availability.T_degrade);
  emlrtAssign(&x_y, m);
  emlrtSetFieldR2017b(w_y, 0, "T_degrade", x_y, 0);
  y_y = nullptr;
  m = emlrtCreateDoubleScalar(u.availability.T_lost);
  emlrtAssign(&y_y, m);
  emlrtSetFieldR2017b(w_y, 0, "T_lost", y_y, 1);
  ab_y = nullptr;
  m = emlrtCreateDoubleScalar(u.availability.T_reacq);
  emlrtAssign(&ab_y, m);
  emlrtSetFieldR2017b(w_y, 0, "T_reacq", ab_y, 2);
  bb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.availability.T_clear);
  emlrtAssign(&bb_y, m);
  emlrtSetFieldR2017b(w_y, 0, "T_clear", bb_y, 3);
  cb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.availability.T_settle);
  emlrtAssign(&cb_y, m);
  emlrtSetFieldR2017b(w_y, 0, "T_settle", cb_y, 4);
  db_y = nullptr;
  m = emlrtCreateDoubleScalar(u.availability.tol_time);
  emlrtAssign(&db_y, m);
  emlrtSetFieldR2017b(w_y, 0, "tol_time", db_y, 5);
  eb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.availability.k_fresh);
  emlrtAssign(&eb_y, m);
  emlrtSetFieldR2017b(w_y, 0, "k_fresh", eb_y, 6);
  fb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.availability.tau_floor);
  emlrtAssign(&fb_y, m);
  emlrtSetFieldR2017b(w_y, 0, "tau_floor", fb_y, 7);
  gb_y = nullptr;
  m = emlrtCreateLogicalArray(1, &i);
  emlrtInitLogicalArray(7, m, &u.availability.present[0]);
  emlrtAssign(&gb_y, m);
  emlrtSetFieldR2017b(w_y, 0, "present", gb_y, 8);
  hb_y = nullptr;
  m = emlrtCreateNumericArray(1, (const void *)&i1, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  for (int32_T b_i{0}; b_i < 7; b_i++) {
    pData[b_i] = u.availability.period[b_i];
  }
  emlrtAssign(&hb_y, m);
  emlrtSetFieldR2017b(w_y, 0, "period", hb_y, 9);
  ib_y = nullptr;
  m = emlrtCreateNumericArray(1, (const void *)&i2, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  for (int32_T b_i{0}; b_i < 7; b_i++) {
    pData[b_i] = u.availability.stale_limit[b_i];
  }
  emlrtAssign(&ib_y, m);
  emlrtSetFieldR2017b(w_y, 0, "stale_limit", ib_y, 10);
  jb_y = nullptr;
  m = emlrtCreateNumericArray(1, (const void *)&i3, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  for (int32_T b_i{0}; b_i < 7; b_i++) {
    pData[b_i] = u.availability.tau_fresh[b_i];
  }
  emlrtAssign(&jb_y, m);
  emlrtSetFieldR2017b(w_y, 0, "tau_fresh", jb_y, 11);
  kb_y = nullptr;
  m = emlrtCreateLogicalScalar(u.availability.config_valid);
  emlrtAssign(&kb_y, m);
  emlrtSetFieldR2017b(w_y, 0, "config_valid", kb_y, 12);
  emlrtSetFieldR2017b(y, 0, "availability", w_y, 3);
  lb_y = nullptr;
  emlrtAssign(&lb_y,
              emlrtCreateStructMatrix(1, 1, 9, (const char_T **)&sv3[0]));
  mb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.fdir.G_nom);
  emlrtAssign(&mb_y, m);
  emlrtSetFieldR2017b(lb_y, 0, "G_nom", mb_y, 0);
  nb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.fdir.thr_B2);
  emlrtAssign(&nb_y, m);
  emlrtSetFieldR2017b(lb_y, 0, "thr_B2", nb_y, 1);
  ob_y = nullptr;
  m = emlrtCreateDoubleScalar(u.fdir.eps_dr_rad);
  emlrtAssign(&ob_y, m);
  emlrtSetFieldR2017b(lb_y, 0, "eps_dr_rad", ob_y, 2);
  pb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.fdir.u_floor);
  emlrtAssign(&pb_y, m);
  emlrtSetFieldR2017b(lb_y, 0, "u_floor", pb_y, 3);
  qb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.fdir.t_warmup_s);
  emlrtAssign(&qb_y, m);
  emlrtSetFieldR2017b(lb_y, 0, "t_warmup_s", qb_y, 4);
  rb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.fdir.Np);
  emlrtAssign(&rb_y, m);
  emlrtSetFieldR2017b(lb_y, 0, "Np", rb_y, 5);
  sb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.fdir.persist_s);
  emlrtAssign(&sb_y, m);
  emlrtSetFieldR2017b(lb_y, 0, "persist_s", sb_y, 6);
  tb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.fdir.dt);
  emlrtAssign(&tb_y, m);
  emlrtSetFieldR2017b(lb_y, 0, "dt", tb_y, 7);
  ub_y = nullptr;
  m = emlrtCreateLogicalScalar(u.fdir.config_valid);
  emlrtAssign(&ub_y, m);
  emlrtSetFieldR2017b(lb_y, 0, "config_valid", ub_y, 8);
  emlrtSetFieldR2017b(y, 0, "fdir", lb_y, 4);
  vb_y = nullptr;
  m = emlrtCreateDoubleScalar(u.safe_thrust);
  emlrtAssign(&vb_y, m);
  emlrtSetFieldR2017b(y, 0, "safe_thrust", vb_y, 5);
  wb_y = nullptr;
  m = emlrtCreateNumericMatrix(1, 1, mxUINT32_CLASS, mxREAL);
  *static_cast<uint32_T *>(emlrtMxGetData(m)) = u.guidance_divider;
  emlrtAssign(&wb_y, m);
  emlrtSetFieldR2017b(y, 0, "guidance_divider", wb_y, 6);
  xb_y = nullptr;
  m = emlrtCreateNumericMatrix(1, 1, mxUINT32_CLASS, mxREAL);
  *static_cast<uint32_T *>(emlrtMxGetData(m)) = u.arm_min_healthy_ticks;
  emlrtAssign(&xb_y, m);
  emlrtSetFieldR2017b(y, 0, "arm_min_healthy_ticks", xb_y, 7);
  yb_y = nullptr;
  m = emlrtCreateLogicalScalar(u.config_valid);
  emlrtAssign(&yb_y, m);
  emlrtSetFieldR2017b(y, 0, "config_valid", yb_y, 8);
  return y;
}

//
// Arguments    : const struct12_T &u
// Return Type  : const mxArray *
//
static const mxArray *emlrt_marshallOut(const struct12_T &u)
{
  static const int32_T iv[2]{18, 18};
  static const int32_T i{3};
  static const int32_T i1{3};
  static const int32_T i10{7};
  static const int32_T i11{7};
  static const int32_T i12{7};
  static const int32_T i2{4};
  static const int32_T i3{3};
  static const int32_T i4{3};
  static const int32_T i5{3};
  static const int32_T i7{7};
  static const int32_T i8{7};
  static const int32_T i9{7};
  static const char_T *sv[15]{"initialized",
                              "p",
                              "v",
                              "q",
                              "bg",
                              "ba",
                              "c",
                              "P",
                              "last_seq",
                              "have_seq",
                              "last_ts",
                              "have_ts",
                              "last_accept_t",
                              "have_accept_t",
                              "est_seq"};
  const mxArray *b_y;
  const mxArray *c_y;
  const mxArray *d_y;
  const mxArray *e_y;
  const mxArray *f_y;
  const mxArray *g_y;
  const mxArray *h_y;
  const mxArray *i_y;
  const mxArray *j_y;
  const mxArray *k_y;
  const mxArray *l_y;
  const mxArray *m;
  const mxArray *m_y;
  const mxArray *n_y;
  const mxArray *o_y;
  const mxArray *p_y;
  const mxArray *y;
  real_T *pData;
  int32_T i6;
  uint32_T *b_pData;
  y = nullptr;
  emlrtAssign(&y, emlrtCreateStructMatrix(1, 1, 15, (const char_T **)&sv[0]));
  b_y = nullptr;
  m = emlrtCreateLogicalScalar(u.initialized);
  emlrtAssign(&b_y, m);
  emlrtSetFieldR2017b(y, 0, "initialized", b_y, 0);
  c_y = nullptr;
  m = emlrtCreateNumericArray(1, (const void *)&i, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  pData[0] = u.p[0];
  pData[1] = u.p[1];
  pData[2] = u.p[2];
  emlrtAssign(&c_y, m);
  emlrtSetFieldR2017b(y, 0, "p", c_y, 1);
  d_y = nullptr;
  m = emlrtCreateNumericArray(1, (const void *)&i1, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  pData[0] = u.v[0];
  pData[1] = u.v[1];
  pData[2] = u.v[2];
  emlrtAssign(&d_y, m);
  emlrtSetFieldR2017b(y, 0, "v", d_y, 2);
  e_y = nullptr;
  m = emlrtCreateNumericArray(1, (const void *)&i2, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  pData[0] = u.q[0];
  pData[1] = u.q[1];
  pData[2] = u.q[2];
  pData[3] = u.q[3];
  emlrtAssign(&e_y, m);
  emlrtSetFieldR2017b(y, 0, "q", e_y, 3);
  f_y = nullptr;
  m = emlrtCreateNumericArray(1, (const void *)&i3, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  pData[0] = u.bg[0];
  pData[1] = u.bg[1];
  pData[2] = u.bg[2];
  emlrtAssign(&f_y, m);
  emlrtSetFieldR2017b(y, 0, "bg", f_y, 4);
  g_y = nullptr;
  m = emlrtCreateNumericArray(1, (const void *)&i4, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  pData[0] = u.ba[0];
  pData[1] = u.ba[1];
  pData[2] = u.ba[2];
  emlrtAssign(&g_y, m);
  emlrtSetFieldR2017b(y, 0, "ba", g_y, 5);
  h_y = nullptr;
  m = emlrtCreateNumericArray(1, (const void *)&i5, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  pData[0] = u.c[0];
  pData[1] = u.c[1];
  pData[2] = u.c[2];
  emlrtAssign(&h_y, m);
  emlrtSetFieldR2017b(y, 0, "c", h_y, 6);
  i_y = nullptr;
  m = emlrtCreateNumericArray(2, (const void *)&iv[0], mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  i6 = 0;
  for (int32_T b_i{0}; b_i < 18; b_i++) {
    for (int32_T c_i{0}; c_i < 18; c_i++) {
      pData[i6 + c_i] = u.P[c_i + 18 * b_i];
    }
    i6 += 18;
  }
  emlrtAssign(&i_y, m);
  emlrtSetFieldR2017b(y, 0, "P", i_y, 7);
  j_y = nullptr;
  m = emlrtCreateNumericArray(1, (const void *)&i7, mxUINT32_CLASS, mxREAL);
  b_pData = static_cast<uint32_T *>(emlrtMxGetData(m));
  for (int32_T b_i{0}; b_i < 7; b_i++) {
    b_pData[b_i] = u.last_seq[b_i];
  }
  emlrtAssign(&j_y, m);
  emlrtSetFieldR2017b(y, 0, "last_seq", j_y, 8);
  k_y = nullptr;
  m = emlrtCreateLogicalArray(1, &i8);
  emlrtInitLogicalArray(7, m, &u.have_seq[0]);
  emlrtAssign(&k_y, m);
  emlrtSetFieldR2017b(y, 0, "have_seq", k_y, 9);
  l_y = nullptr;
  m = emlrtCreateNumericArray(1, (const void *)&i9, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  for (int32_T b_i{0}; b_i < 7; b_i++) {
    pData[b_i] = u.last_ts[b_i];
  }
  emlrtAssign(&l_y, m);
  emlrtSetFieldR2017b(y, 0, "last_ts", l_y, 10);
  m_y = nullptr;
  m = emlrtCreateLogicalArray(1, &i10);
  emlrtInitLogicalArray(7, m, &u.have_ts[0]);
  emlrtAssign(&m_y, m);
  emlrtSetFieldR2017b(y, 0, "have_ts", m_y, 11);
  n_y = nullptr;
  m = emlrtCreateNumericArray(1, (const void *)&i11, mxDOUBLE_CLASS, mxREAL);
  pData = emlrtMxGetPr(m);
  for (int32_T b_i{0}; b_i < 7; b_i++) {
    pData[b_i] = u.last_accept_t[b_i];
  }
  emlrtAssign(&n_y, m);
  emlrtSetFieldR2017b(y, 0, "last_accept_t", n_y, 12);
  o_y = nullptr;
  m = emlrtCreateLogicalArray(1, &i12);
  emlrtInitLogicalArray(7, m, &u.have_accept_t[0]);
  emlrtAssign(&o_y, m);
  emlrtSetFieldR2017b(y, 0, "have_accept_t", o_y, 13);
  p_y = nullptr;
  m = emlrtCreateNumericMatrix(1, 1, mxUINT32_CLASS, mxREAL);
  *static_cast<uint32_T *>(emlrtMxGetData(m)) = u.est_seq;
  emlrtAssign(&p_y, m);
  emlrtSetFieldR2017b(y, 0, "est_seq", p_y, 14);
  return y;
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *u
//                const emlrtMsgIdentifier *parentId
//                real_T y[324]
// Return Type  : void
//
static void f_emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId,
                               real_T y[324])
{
  n_emlrt_marshallIn(sp, emlrtAlias(u), parentId, y);
  emlrtDestroyArray(&u);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *u
//                const emlrtMsgIdentifier *parentId
// Return Type  : struct10_T
//
static struct10_T f_emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                                     const emlrtMsgIdentifier *parentId)
{
  static const int32_T dims{0};
  static const char_T *fieldNames[7]{
      "prev_delta_r", "prev_delta_e", "int_angle",  "int_rate",
      "rate_filt",    "prev_e_rate",  "initialized"};
  emlrtMsgIdentifier thisId;
  struct10_T y;
  thisId.fParent = parentId;
  thisId.bParentIsCell = false;
  emlrtCheckStructR2012b((emlrtConstCTX)&sp, parentId, u, 7,
                         (const char_T **)&fieldNames[0], 0U,
                         (const void *)&dims);
  thisId.fIdentifier = "prev_delta_r";
  y.prev_delta_r =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      0, "prev_delta_r")),
                       &thisId);
  thisId.fIdentifier = "prev_delta_e";
  y.prev_delta_e =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      1, "prev_delta_e")),
                       &thisId);
  thisId.fIdentifier = "int_angle";
  y.int_angle = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 2, "int_angle")),
      &thisId);
  thisId.fIdentifier = "int_rate";
  y.int_rate = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 3, "int_rate")),
      &thisId);
  thisId.fIdentifier = "rate_filt";
  y.rate_filt = emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 4, "rate_filt")),
      &thisId);
  thisId.fIdentifier = "prev_e_rate";
  y.prev_e_rate =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      5, "prev_e_rate")),
                       &thisId);
  thisId.fIdentifier = "initialized";
  y.initialized =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      6, "initialized")),
                       &thisId);
  emlrtDestroyArray(&u);
  return y;
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *u
//                const emlrtMsgIdentifier *parentId
//                real_T y[5]
// Return Type  : void
//
static void g_emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId, real_T y[5])
{
  o_emlrt_marshallIn(sp, emlrtAlias(u), parentId, y);
  emlrtDestroyArray(&u);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *u
//                const emlrtMsgIdentifier *parentId
// Return Type  : uint8_T
//
static uint8_T g_emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                                  const emlrtMsgIdentifier *parentId)
{
  uint8_T y;
  y = m_emlrt_marshallIn(sp, emlrtAlias(u), parentId);
  emlrtDestroyArray(&u);
  return y;
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *u
//                const emlrtMsgIdentifier *parentId
// Return Type  : struct14_T
//
static struct14_T h_emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                                     const emlrtMsgIdentifier *parentId)
{
  static const int32_T dims{0};
  static const char_T *fieldNames[7]{
      "initialized",      "persist_count", "anomaly_latched", "alarm_time_s",
      "alarm_time_valid", "last_seq",      "have_seq"};
  emlrtMsgIdentifier thisId;
  struct14_T y;
  thisId.fParent = parentId;
  thisId.bParentIsCell = false;
  emlrtCheckStructR2012b((emlrtConstCTX)&sp, parentId, u, 7,
                         (const char_T **)&fieldNames[0], 0U,
                         (const void *)&dims);
  thisId.fIdentifier = "initialized";
  y.initialized =
      b_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u,
                                                        0, 0, "initialized")),
                         &thisId);
  thisId.fIdentifier = "persist_count";
  y.persist_count =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      1, "persist_count")),
                       &thisId);
  thisId.fIdentifier = "anomaly_latched";
  y.anomaly_latched =
      b_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b(
                             (emlrtConstCTX)&sp, u, 0, 2, "anomaly_latched")),
                         &thisId);
  thisId.fIdentifier = "alarm_time_s";
  y.alarm_time_s =
      emlrt_marshallIn(sp,
                       emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0,
                                                      3, "alarm_time_s")),
                       &thisId);
  thisId.fIdentifier = "alarm_time_valid";
  y.alarm_time_valid =
      b_emlrt_marshallIn(sp,
                         emlrtAlias(emlrtGetFieldR2017b(
                             (emlrtConstCTX)&sp, u, 0, 4, "alarm_time_valid")),
                         &thisId);
  thisId.fIdentifier = "last_seq";
  y.last_seq = e_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 5, "last_seq")),
      &thisId);
  thisId.fIdentifier = "have_seq";
  y.have_seq = b_emlrt_marshallIn(
      sp,
      emlrtAlias(emlrtGetFieldR2017b((emlrtConstCTX)&sp, u, 0, 6, "have_seq")),
      &thisId);
  emlrtDestroyArray(&u);
  return y;
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *u
//                const emlrtMsgIdentifier *parentId
//                real_T y[96]
// Return Type  : void
//
static void h_emlrt_marshallIn(const emlrtStack &sp, const mxArray *u,
                               const emlrtMsgIdentifier *parentId, real_T y[96])
{
  p_emlrt_marshallIn(sp, emlrtAlias(u), parentId, y);
  emlrtDestroyArray(&u);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *src
//                const emlrtMsgIdentifier *msgId
//                real_T ret[4]
// Return Type  : void
//
static void i_emlrt_marshallIn(const emlrtStack &sp, const mxArray *src,
                               const emlrtMsgIdentifier *msgId, real_T ret[4])
{
  static const int32_T dims[2]{1, 4};
  real_T(*r)[4];
  emlrtCheckBuiltInR2012b((emlrtConstCTX)&sp, msgId, src, "double", false, 2U,
                          (const void *)&dims[0]);
  r = (real_T(*)[4])emlrtMxGetData(src);
  ret[0] = (*r)[0];
  ret[1] = (*r)[1];
  ret[2] = (*r)[2];
  ret[3] = (*r)[3];
  emlrtDestroyArray(&src);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *src
//                const emlrtMsgIdentifier *msgId
// Return Type  : real_T
//
static real_T i_emlrt_marshallIn(const emlrtStack &sp, const mxArray *src,
                                 const emlrtMsgIdentifier *msgId)
{
  static const int32_T dims{0};
  real_T ret;
  emlrtCheckBuiltInR2012b((emlrtConstCTX)&sp, msgId, src, "double", false, 0U,
                          (const void *)&dims);
  ret = *static_cast<real_T *>(emlrtMxGetData(src));
  emlrtDestroyArray(&src);
  return ret;
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *src
//                const emlrtMsgIdentifier *msgId
//                real_T ret[7]
// Return Type  : void
//
static void j_emlrt_marshallIn(const emlrtStack &sp, const mxArray *src,
                               const emlrtMsgIdentifier *msgId, real_T ret[7])
{
  static const int32_T dims{7};
  real_T(*r)[7];
  emlrtCheckBuiltInR2012b((emlrtConstCTX)&sp, msgId, src, "double", false, 1U,
                          (const void *)&dims);
  r = (real_T(*)[7])emlrtMxGetData(src);
  for (int32_T i{0}; i < 7; i++) {
    ret[i] = (*r)[i];
  }
  emlrtDestroyArray(&src);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *src
//                const emlrtMsgIdentifier *msgId
// Return Type  : boolean_T
//
static boolean_T j_emlrt_marshallIn(const emlrtStack &sp, const mxArray *src,
                                    const emlrtMsgIdentifier *msgId)
{
  static const int32_T dims{0};
  boolean_T ret;
  emlrtCheckBuiltInR2012b((emlrtConstCTX)&sp, msgId, src, "logical", false, 0U,
                          (const void *)&dims);
  ret = *emlrtMxGetLogicals(src);
  emlrtDestroyArray(&src);
  return ret;
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *src
//                const emlrtMsgIdentifier *msgId
//                boolean_T ret[7]
// Return Type  : void
//
static void k_emlrt_marshallIn(const emlrtStack &sp, const mxArray *src,
                               const emlrtMsgIdentifier *msgId,
                               boolean_T ret[7])
{
  static const int32_T dims{7};
  boolean_T(*r)[7];
  emlrtCheckBuiltInR2012b((emlrtConstCTX)&sp, msgId, src, "logical", false, 1U,
                          (const void *)&dims);
  r = (boolean_T(*)[7])emlrtMxGetLogicals(src);
  for (int32_T i{0}; i < 7; i++) {
    ret[i] = (*r)[i];
  }
  emlrtDestroyArray(&src);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *src
//                const emlrtMsgIdentifier *msgId
//                real_T ret[3]
// Return Type  : void
//
static void l_emlrt_marshallIn(const emlrtStack &sp, const mxArray *src,
                               const emlrtMsgIdentifier *msgId, real_T ret[3])
{
  static const int32_T dims{3};
  real_T(*r)[3];
  emlrtCheckBuiltInR2012b((emlrtConstCTX)&sp, msgId, src, "double", false, 1U,
                          (const void *)&dims);
  r = (real_T(*)[3])emlrtMxGetData(src);
  ret[0] = (*r)[0];
  ret[1] = (*r)[1];
  ret[2] = (*r)[2];
  emlrtDestroyArray(&src);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *src
//                const emlrtMsgIdentifier *msgId
// Return Type  : uint32_T
//
static uint32_T l_emlrt_marshallIn(const emlrtStack &sp, const mxArray *src,
                                   const emlrtMsgIdentifier *msgId)
{
  static const int32_T dims{0};
  uint32_T ret;
  emlrtCheckBuiltInR2012b((emlrtConstCTX)&sp, msgId, src, "uint32", false, 0U,
                          (const void *)&dims);
  ret = *static_cast<uint32_T *>(emlrtMxGetData(src));
  emlrtDestroyArray(&src);
  return ret;
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *src
//                const emlrtMsgIdentifier *msgId
//                real_T ret[4]
// Return Type  : void
//
static void m_emlrt_marshallIn(const emlrtStack &sp, const mxArray *src,
                               const emlrtMsgIdentifier *msgId, real_T ret[4])
{
  static const int32_T dims{4};
  real_T(*r)[4];
  emlrtCheckBuiltInR2012b((emlrtConstCTX)&sp, msgId, src, "double", false, 1U,
                          (const void *)&dims);
  r = (real_T(*)[4])emlrtMxGetData(src);
  ret[0] = (*r)[0];
  ret[1] = (*r)[1];
  ret[2] = (*r)[2];
  ret[3] = (*r)[3];
  emlrtDestroyArray(&src);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *src
//                const emlrtMsgIdentifier *msgId
// Return Type  : uint8_T
//
static uint8_T m_emlrt_marshallIn(const emlrtStack &sp, const mxArray *src,
                                  const emlrtMsgIdentifier *msgId)
{
  static const int32_T dims{0};
  uint8_T ret;
  emlrtCheckBuiltInR2012b((emlrtConstCTX)&sp, msgId, src, "uint8", false, 0U,
                          (const void *)&dims);
  ret = *static_cast<uint8_T *>(emlrtMxGetData(src));
  emlrtDestroyArray(&src);
  return ret;
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *src
//                const emlrtMsgIdentifier *msgId
//                real_T ret[324]
// Return Type  : void
//
static void n_emlrt_marshallIn(const emlrtStack &sp, const mxArray *src,
                               const emlrtMsgIdentifier *msgId, real_T ret[324])
{
  static const int32_T dims[2]{18, 18};
  real_T(*r)[324];
  emlrtCheckBuiltInR2012b((emlrtConstCTX)&sp, msgId, src, "double", false, 2U,
                          (const void *)&dims[0]);
  r = (real_T(*)[324])emlrtMxGetData(src);
  for (int32_T i{0}; i < 324; i++) {
    ret[i] = (*r)[i];
  }
  emlrtDestroyArray(&src);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *src
//                const emlrtMsgIdentifier *msgId
//                real_T ret[5]
// Return Type  : void
//
static void o_emlrt_marshallIn(const emlrtStack &sp, const mxArray *src,
                               const emlrtMsgIdentifier *msgId, real_T ret[5])
{
  static const int32_T dims{5};
  real_T(*r)[5];
  emlrtCheckBuiltInR2012b((emlrtConstCTX)&sp, msgId, src, "double", false, 1U,
                          (const void *)&dims);
  r = (real_T(*)[5])emlrtMxGetData(src);
  for (int32_T i{0}; i < 5; i++) {
    ret[i] = (*r)[i];
  }
  emlrtDestroyArray(&src);
}

//
// Arguments    : const emlrtStack &sp
//                const mxArray *src
//                const emlrtMsgIdentifier *msgId
//                real_T ret[96]
// Return Type  : void
//
static void p_emlrt_marshallIn(const emlrtStack &sp, const mxArray *src,
                               const emlrtMsgIdentifier *msgId, real_T ret[96])
{
  static const int32_T dims{96};
  real_T(*r)[96];
  emlrtCheckBuiltInR2012b((emlrtConstCTX)&sp, msgId, src, "double", false, 1U,
                          (const void *)&dims);
  r = (real_T(*)[96])emlrtMxGetData(src);
  for (int32_T i{0}; i < 96; i++) {
    ret[i] = (*r)[i];
  }
  emlrtDestroyArray(&src);
}

//
// Arguments    : const mxArray *prhs
//                const mxArray **plhs
// Return Type  : void
//
void auv_runtime_codegen_init_api(const mxArray *prhs, const mxArray **plhs)
{
  emlrtStack st{
      nullptr, // site
      nullptr, // tls
      nullptr  // prev
  };
  struct0_T cfg;
  struct5_T params;
  st.tls = emlrtRootTLSGlobal;
  // Marshall function inputs
  emlrt_marshallIn(st, emlrtAliasP(prhs), "cfg", cfg);
  // Invoke the target function
  auv_runtime_codegen_init(&cfg, &params);
  // Marshall function outputs
  *plhs = emlrt_marshallOut(params);
}

//
// Arguments    : void
// Return Type  : void
//
void auv_runtime_codegen_init_atexit()
{
  emlrtStack st{
      nullptr, // site
      nullptr, // tls
      nullptr  // prev
  };
  mexFunctionCreateRootTLS();
  st.tls = emlrtRootTLSGlobal;
  emlrtPushHeapReferenceStackR2021a(&st, false, nullptr,
                                    (void *)&emlrtExitTimeCleanupDtorFcn,
                                    nullptr, nullptr, nullptr);
  emlrtEnterRtStackR2012b(&st);
  emlrtDestroyRootTLS(&emlrtRootTLSGlobal);
  auv_runtime_codegen_init_xil_terminate();
  auv_runtime_codegen_init_xil_shutdown();
  emlrtExitTimeCleanup(&emlrtContextGlobal);
}

//
// Arguments    : void
// Return Type  : void
//
void auv_runtime_codegen_init_initialize()
{
  emlrtStack st{
      nullptr, // site
      nullptr, // tls
      nullptr  // prev
  };
  mexFunctionCreateRootTLS();
  st.tls = emlrtRootTLSGlobal;
  emlrtClearAllocCountR2012b(&st, false, 0U, nullptr);
  emlrtEnterRtStackR2012b(&st);
  emlrtFirstTimeR2012b(emlrtRootTLSGlobal);
}

//
// Arguments    : void
// Return Type  : void
//
void auv_runtime_codegen_init_terminate()
{
  emlrtDestroyRootTLS(&emlrtRootTLSGlobal);
}

//
// Arguments    : const mxArray *prhs
//                const mxArray **plhs
// Return Type  : void
//
void auv_runtime_codegen_reset_api(const mxArray *prhs, const mxArray **plhs)
{
  emlrtStack st{
      nullptr, // site
      nullptr, // tls
      nullptr  // prev
  };
  struct5_T params;
  struct9_T state;
  st.tls = emlrtRootTLSGlobal;
  // Marshall function inputs
  emlrt_marshallIn(st, emlrtAliasP(prhs), "params", params);
  // Invoke the target function
  auv_runtime_codegen_reset(&params, &state);
  // Marshall function outputs
  *plhs = emlrt_marshallOut(state);
}

//
// Arguments    : const mxArray * const prhs[3]
//                int32_T nlhs
//                const mxArray *plhs[2]
// Return Type  : void
//
void auv_runtime_codegen_step_api(const mxArray *const prhs[3], int32_T nlhs,
                                  const mxArray *plhs[2])
{
  emlrtStack st{
      nullptr, // site
      nullptr, // tls
      nullptr  // prev
  };
  struct15_T in;
  struct17_T out;
  struct5_T params;
  struct9_T state;
  st.tls = emlrtRootTLSGlobal;
  // Marshall function inputs
  emlrt_marshallIn(st, emlrtAliasP(prhs[0]), "params", params);
  emlrt_marshallIn(st, emlrtAliasP(prhs[1]), "state", state);
  emlrt_marshallIn(st, emlrtAliasP(prhs[2]), "in", in);
  // Invoke the target function
  auv_runtime_codegen_step(&params, &state, &in, &out);
  // Marshall function outputs
  plhs[0] = emlrt_marshallOut(state);
  if (nlhs > 1) {
    plhs[1] = emlrt_marshallOut(out);
  }
}

//
// File trailer for _coder_auv_runtime_codegen_init_api.cpp
//
// [EOF]
//
