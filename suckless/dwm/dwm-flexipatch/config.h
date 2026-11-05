/* See LICENSE file for copyright and license details. */

/* Helper macros for spawning commands */
#define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }
#define CMD(...)   { .v = (const char*[]){ __VA_ARGS__, NULL } }

/* appearance */
static const unsigned int borderpx       = 0;   /* border pixel of windows */
static const unsigned int snap           = 32;  /* snap pixel */
static const unsigned int gappih         = 0;  /* horiz inner gap between windows */
static const unsigned int gappiv         = 0;  /* vert inner gap between windows */
static const unsigned int gappoh         = 0;  /* horiz outer gap between windows and screen edge */
static const unsigned int gappov         = 0;  /* vert outer gap between windows and screen edge */
static const int smartgaps_fact          = 1;   /* gap factor when there is only one client; 0 = no gaps, 3 = 3x outer gaps */
static const int showbar                 = 1;   /* 0 means no bar */
static const int topbar                  = 1;   /* 0 means bottom bar */
static const int bar_height              = 0;   /* 0 means derive from font, >= 1 explicit height */
#define ICONSIZE 14    /* icon size */
#define ICONSPACING 5  /* space between icon and title */
static const int focusonwheel            = 0;
static const unsigned int systrayspacing = 2;   /* systray spacing */
static const int showsystray             = 1;   /* 0 means no systray */
static const unsigned int ulinepad = 0;         /* horizontal padding between the underline and tag */
static const unsigned int ulinestroke  = 2;     /* thickness / height of the underline */
static const unsigned int ulinevoffset = 0;     /* how far above the bottom of the bar the line should appear */
static const int ulineall = 0;                  /* 1 to show underline on all tags, 0 for just the active ones */
static const int ulinetop = 0;                  /* 1 to show the underline above the tags, rather than under */

/* Indicators: see patch/bar_indicators.h for options */
static const char *fonts[]               = { "Hack Nerd Font:size=10" };
static const char dmenufont[]            = "Hack Nerd Font:size=10";

// Colors for config without xrdb patch
static char grey_color_10[]        = "#222222"; // bg
static char grey_color_20[]        = "#444444"; // border
static char grey_color_30[]        = "#666666"; // bg sel
static char grey_color_40[]        = "#bbbbbb"; // fg

static char white_color[]          = "#eeeeee"; // fg sel

static char color6[]               = "#aa6292";

#define FG_COLOR grey_color_40
#define BORDER_COLOR grey_color_20
#define BG_COLOR grey_color_10
#define FG_SEL_COLOR white_color
#define BG_SEL_COLOR grey_color_30
#define ACCENT_COLOR grey_color_30
#define LT_SYM_COLOR color6

static const unsigned int baralpha = 0xd0;
static const unsigned int borderalpha = OPAQUE;
static const unsigned int alphas[][3] = {
	/*                       fg      bg        border     */
	[SchemeNorm]         = { OPAQUE, baralpha, borderalpha },
	[SchemeSel]          = { OPAQUE, baralpha, borderalpha },
	[SchemeTagsNorm]     = { OPAQUE, baralpha, borderalpha },
	[SchemeTagsSel]      = { OPAQUE, baralpha, borderalpha },
	[SchemeLtSymbol]     = { OPAQUE, baralpha, borderalpha },
	[SchemeFlexActTTB]   = { OPAQUE, baralpha, borderalpha },
	[SchemeFlexActMONO]  = { OPAQUE, baralpha, borderalpha },
	[SchemeFlexActGRD1]  = { OPAQUE, baralpha, borderalpha },
	[SchemeFlexInaTTB]   = { OPAQUE, baralpha, borderalpha },
	[SchemeFlexInaMONO]  = { OPAQUE, baralpha, borderalpha },
	[SchemeFlexInaGRD1]  = { OPAQUE, baralpha, borderalpha },
	[SchemeFlexSelTTB]   = { OPAQUE, baralpha, borderalpha },
	[SchemeFlexSelMONO]  = { OPAQUE, baralpha, borderalpha },
	[SchemeFlexSelGRD1]  = { OPAQUE, baralpha, borderalpha },
};

static char *colors[][ColCount] = {
	/*                       fg                bg                border                float */
	[SchemeNorm]         = { FG_COLOR,         BG_COLOR,         BORDER_COLOR,         BORDER_COLOR },
	[SchemeSel]          = { FG_COLOR,         BG_COLOR,         BORDER_COLOR,         BORDER_COLOR },
	[SchemeTagsNorm]     = { FG_COLOR,         BG_COLOR,         BORDER_COLOR,         BORDER_COLOR },
	[SchemeTagsSel]      = { FG_COLOR,         BG_COLOR,         BORDER_COLOR,         BORDER_COLOR },
	[SchemeLtSymbol]     = { LT_SYM_COLOR,     BG_COLOR,         BORDER_COLOR,         BORDER_COLOR },
	[SchemeFlexActTTB]   = { FG_COLOR,         BG_COLOR,         BORDER_COLOR,         BORDER_COLOR },
	[SchemeFlexActMONO]  = { FG_COLOR,         BG_COLOR,         BORDER_COLOR,         BORDER_COLOR },
	[SchemeFlexActGRD1]  = { FG_COLOR,         BG_COLOR,         BORDER_COLOR,         BORDER_COLOR },
	[SchemeFlexInaTTB]   = { FG_COLOR,         BG_COLOR,         BORDER_COLOR,         BORDER_COLOR },
	[SchemeFlexInaMONO]  = { FG_COLOR,         BG_COLOR,         BORDER_COLOR,         BORDER_COLOR },
	[SchemeFlexInaGRD1]  = { FG_COLOR,         BG_COLOR,         BORDER_COLOR,         BORDER_COLOR },
	[SchemeFlexSelTTB]   = { FG_SEL_COLOR,     BG_SEL_COLOR,     ACCENT_COLOR,         ACCENT_COLOR },
	[SchemeFlexSelMONO]  = { FG_SEL_COLOR,     BG_SEL_COLOR,     ACCENT_COLOR,         ACCENT_COLOR },
	[SchemeFlexSelGRD1]  = { FG_SEL_COLOR,     BG_SEL_COLOR,     ACCENT_COLOR,         ACCENT_COLOR },
};

// Tags
static char *tagicons[][NUMTAGS] =
{
	[DEFAULT_TAGS]        = { "1", "2", "3", "4", "5", "6", "7", "8", "9" },
};

// Windows rules
static const Rule rules[] = {
	RULE(.wintype = WTYPE "DIALOG", .isfloating = 1)
	RULE(.wintype = WTYPE "UTILITY", .isfloating = 1)
	RULE(.wintype = WTYPE "TOOLBAR", .isfloating = 1)
	RULE(.wintype = WTYPE "SPLASH", .isfloating = 1)
};

// Bar rules
static const BarRule barrules[] = {
	/* monitor   bar    alignment         widthfunc                 drawfunc                clickfunc                hoverfunc                name */
	{ -1,        0,     BAR_ALIGN_LEFT,   width_tags,               draw_tags,              click_tags,              hover_tags,              "tags" },
	{ -1,        0,     BAR_ALIGN_LEFT,   width_ltsymbol,           draw_ltsymbol,          click_ltsymbol,          NULL,                    "layout" },
	{ -1,        0,     BAR_ALIGN_LEFT,   width_systray,            draw_systray,           click_systray,           NULL,                    "systray" },
	{ -1,        0,     BAR_ALIGN_RIGHT,  width_status2d,           draw_status2d,          click_status2d,          NULL,                    "status2d" },
	{ -1,        0,     BAR_ALIGN_NONE,   width_flexwintitle,       draw_flexwintitle,      click_flexwintitle,      NULL,                    "flexwintitle" },
};

// Layouts
static const float mfact        = 0.5;  /* factor of master area size [0.05..0.95] */
static const int nmaster        = 1;    /* number of clients in master area */
static const int resizehints    = 0;    /* 1 means respect size hints in tiled resizals */
static const int lockfullscreen = 1;    /* 1 will force focus on the fullscreen window */
static const int refreshrate    = 120;  /* refresh rate (per second) for client move/resize */

#define FORCE_VSPLIT 1

static const Layout layouts[] = {
	/* first entry is default */
	/* symbol     arrange function */
	{ "[]=",      tile },
	{ "[M]",      monocle },
	{ "!!!",      nrowgrid },
};

// Structure and func for custom columns layout
typedef struct {
    const Layout *layout;
    int nmaster;
} LayoutPreset;

static const LayoutPreset layoutpresets[] = {
  { &layouts[0], 1 },
  { &layouts[1], 1 },
	{ &layouts[2], 0 },
};

static void setlayoutpreset(const Arg *arg)
{
    const LayoutPreset *preset = arg->v;
    setlayout(&(Arg){ .v = (void *)preset->layout });
    selmon->nmaster = preset->nmaster;
    arrange(selmon);
}

// Key definitions
#define MODKEY Mod4Mask
#define TAGKEYS(KEY,TAG) \
	{ MODKEY,                       KEY,      view,           {.ui = 1 << TAG} }, \
	{ MODKEY|ControlMask,           KEY,      toggleview,     {.ui = 1 << TAG} }, \
	{ MODKEY|ShiftMask,             KEY,      tag,            {.ui = 1 << TAG} }, \
	{ MODKEY|ControlMask|ShiftMask, KEY,      toggletag,      {.ui = 1 << TAG} },

// Commands
static char dmenumon[8]; /* component of dmenucmd, manipulated in spawn() */
static const char *dmenucmd[] = {
	"j4-dmenu-desktop",
	"--dmenu=dmenu -i -p '>' -sb '#666666' -sf '#eeeeee' -nb '#222222' -fn 'Hack Nerd Font:size=10'",
	"--no-generic",
	NULL
};
static const char *termcmd[]  = { "x-terminal-emulator", NULL };

static const Key keys[] = {
	/* modifier                     key            function                argument */
	{ MODKEY,                       XK_d,          spawn,                  {.v = dmenucmd } },
	{ MODKEY, 				              XK_Return,     spawn,                  {.v = termcmd } },
	{ MODKEY,                       XK_b,          togglebar,              {0} },
	{ MODKEY,                       XK_j,          focusstack,             {.i = +1 } },
	{ MODKEY,                       XK_k,          focusstack,             {.i = -1 } },
	{ MODKEY,                       XK_h,          setmfact,               {.f = -0.05} },
	{ MODKEY,                       XK_l,          setmfact,               {.f = +0.05} },
	{ MODKEY,                       XK_BackSpace,  zoom,                   {0} },
	{ MODKEY,                       XK_q,          killclient,             {0} },
	{ MODKEY|ShiftMask,             XK_e,          quit,                   {0} },
	{ MODKEY,                       XK_t,          setlayoutpreset,        {.v = &layoutpresets[0]} },
	{ MODKEY,                       XK_m,          setlayoutpreset,        {.v = &layoutpresets[1]} },
	{ MODKEY,                       XK_c,          setlayoutpreset,        {.v = &layoutpresets[2]} },
	{ MODKEY,                       XK_space,      togglefloating,         {0} },
	TAGKEYS(                        XK_1,                                  0)
	TAGKEYS(                        XK_2,                                  1)
	TAGKEYS(                        XK_3,                                  2)
	TAGKEYS(                        XK_4,                                  3)
	TAGKEYS(                        XK_5,                                  4)
	TAGKEYS(                        XK_6,                                  5)
	TAGKEYS(                        XK_7,                                  6)
	TAGKEYS(                        XK_8,                                  7)
	TAGKEYS(                        XK_9,                                  8)
};

// Button definitions
// Click can be ClkTagBar, ClkLtSymbol, ClkStatusText, ClkWinTitle, ClkClientWin, or ClkRootWin
static const Button buttons[] = {
	/* click                event mask           button          function        argument */
	{ ClkLtSymbol,          0,                   Button1,        setlayout,      {0} },
	{ ClkLtSymbol,          0,                   Button3,        setlayout,      {.v = &layouts[2]} },
	{ ClkWinTitle,          0,                   Button2,        zoom,           {0} },
	{ ClkStatusText,        0,                   Button2,        spawn,          {.v = termcmd } },
	{ ClkClientWin,         MODKEY,              Button1,        movemouse,      {0} },
	{ ClkClientWin,         MODKEY,              Button2,        togglefloating, {0} },
	{ ClkClientWin,         MODKEY,              Button3,        resizemouse,    {0} },
	{ ClkTagBar,            0,                   Button1,        view,           {0} },
	{ ClkTagBar,            0,                   Button3,        toggleview,     {0} },
	{ ClkTagBar,            MODKEY,              Button1,        tag,            {0} },
	{ ClkTagBar,            MODKEY,              Button3,        toggletag,      {0} },
};
