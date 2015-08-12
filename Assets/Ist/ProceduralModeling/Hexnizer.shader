﻿Shader "Ist/ProceduralModeling/Hexnizer" {
Properties {
    _GridSize("Grid Size", Float) = 1.2
    _HexRadius("Hex Radius", Float) = 0.35
    _BumpHeight("Bump Height", Float) = 0.15
    _EdgeWidth("Edge Width", Float) = 0.025
    _EdgeHeight("Edge Height", Float) = 0.25
    _EdgeChopping("Edge Chopping", Int) = 1

    _Color("Albedo", Color) = (0.75, 0.75, 0.8, 1.0)
    _SpecularColor("Specular", Color) = (0.2, 0.2, 0.2, 1.0)
    _Smoothness("Smoothness", Range(0, 1)) = 0.7
    _EmissionColor("Emission", Color) = (0.0, 0.0, 0.0, 1.0)

    _OffsetPosition("OffsetPosition", Vector) = (0, 0, 0, 0)
    _Scale("Scale", Vector) = (1, 1, 1, 0)
    _CutoutDistance("Cutout Distance", Float) = 0.01

    _ZTest("ZTest", Int) = 4
}

CGINCLUDE
#define MAX_MARCH_STEPS 8
//#define ENABLE_TRACEBACK 1
//#define MAX_TRACEBACK_STEPS 32
#define ENABLE_BOX_CLIPPING 1
#define ENABLE_DEPTH_OUTPUT 1

#define HEX_DIR y
#define HEX_PLANE xz

#include "ProceduralModeling.cginc"

float _GridSize;
float _HexRadius;
float _BumpHeight;
float _EdgeWidth;
float _EdgeHeight;
int _EdgeChopping;


float2 grid;
float2 grid_rcp;
float2 grid_half;
float radius;

void initialize(inout raymarch_data rmd)
{
    grid = float2(0.692, 0.4) * _GridSize;
    grid_rcp = rcp(grid);
    grid_half = grid*0.5;
    radius = 0.22 * _HexRadius;
}

float map(float3 pg)
{
    float3 p = localize(pg);

    float2 p1 = modc(p.HEX_PLANE, grid) - grid_half;
    float2 p2 = modc(p.HEX_PLANE + grid_half, grid) - grid_half;
    float h1 = sdHex(float2(p1.x,p1.y), radius);
    float h2 = sdHex(float2(p2.x,p2.y), radius);
    float e1 = max(min(h1, 0.0) + _EdgeWidth, 0.0)*_EdgeHeight;
    float e2 = max(min(h2, 0.0) + _EdgeWidth, 0.0)*_EdgeHeight;

    float2 g1 = float2(floor(p.HEX_PLANE * grid_rcp));
    float2 g2 = float2(floor((p.HEX_PLANE + grid_half) * grid_rcp));

    if(_EdgeChopping) {
        float2 s = _Scale.HEX_PLANE;
        float2 f1 = (abs(g1) + step(0.0, g1)) * grid;
        float2 f2 = abs(g2) * grid + grid_half;
        if (f1.x > s.x*0.5 || f1.y > s.y*0.5) { h1 += grid_half*0.98; }
        if (f2.x > s.x*0.5 || f2.y > s.y*0.5) { h2 += grid_half*0.98; }
    }

    if (_BumpHeight != 0.0) {
        float rxz = iq_rand(g1).x;
        float ryz = iq_rand(g2).x;
        e1 += rxz*_BumpHeight;
        e2 += ryz*_BumpHeight;
    }

    h1 = max(h1, p.HEX_DIR - _Scale.HEX_DIR*0.5 + e1);
    h2 = max(h2, p.HEX_DIR - _Scale.HEX_DIR*0.5 + e2);
    h1 = min(h1, h2);
    return max(h1, 0.0);
}

void posteffect(inout gbuffer_out go, inout raymarch_data rmd)
{
}

#include "Framework.cginc"

ENDCG

SubShader {
    Tags{ "RenderType" = "Opaque" "DisableBatching" = "True" "Queue" = "Geometry+10" }

    Pass{
        Tags{ "LightMode" = "ShadowCaster" }
        Cull Front
        ColorMask 0
        CGPROGRAM
#pragma vertex vert_shadow
#pragma fragment frag_shadow
        ENDCG
    }

    Pass {
        Tags { "LightMode" = "Deferred" }
        Stencil {
            Comp Always
            Pass Replace
            Ref 128
        }
        ZTest [_ZTest]
        Cull Back
CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag_gbuffer
#pragma multi_compile ___ UNITY_HDR_ON
#pragma multi_compile ___ ENABLE_DEPTH_OUTPUT
ENDCG
    }
}

Fallback Off
}