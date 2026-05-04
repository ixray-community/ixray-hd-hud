#include "common.hlsli"

uniform float4 screen_res;

struct v_ui
{
    float4 P : POSITION;
    float4 color : COLOR0;
    float2 uv : TEXCOORD0;
};

struct p_ui
{
    float2 tc0 : TEXCOORD0;
    float4 color : COLOR0;
    float4 hpos : POSITION;
};

p_ui main(v_ui I)
{
    p_ui O;

    I.P.xy += 0.5f;
    O.hpos.x = I.P.x * screen_res.z * 2.0f - 1.0f;
    O.hpos.y = (I.P.y * screen_res.w * 2.0f - 1.0f) * -1.0f;
    O.hpos.zw = I.P.zw;
    O.tc0 = I.uv;
    O.color = I.color.bgra;

    return O;
}
