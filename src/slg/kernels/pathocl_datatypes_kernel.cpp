#include <string>
namespace slg { namespace ocl {
std::string KernelSource_pathocl_datatypes = 
"#line 2 \"pathocl_datatypes.cl\"\n"
"\n"
"/***************************************************************************\n"
" * Copyright 1998-2015 by authors (see AUTHORS.txt)                        *\n"
" *                                                                         *\n"
" *   This file is part of LuxRender.                                       *\n"
" *                                                                         *\n"
" * Licensed under the Apache License, Version 2.0 (the \"License\");         *\n"
" * you may not use this file except in compliance with the License.        *\n"
" * You may obtain a copy of the License at                                 *\n"
" *                                                                         *\n"
" *     http://www.apache.org/licenses/LICENSE-2.0                          *\n"
" *                                                                         *\n"
" * Unless required by applicable law or agreed to in writing, software     *\n"
" * distributed under the License is distributed on an \"AS IS\" BASIS,       *\n"
" * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.*\n"
" * See the License for the specific language governing permissions and     *\n"
" * limitations under the License.                                          *\n"
" ***************************************************************************/\n"
"\n"
"//------------------------------------------------------------------------------\n"
"// Some OpenCL specific definition\n"
"//------------------------------------------------------------------------------\n"
"\n"
"#if defined(SLG_OPENCL_KERNEL)\n"
"\n"
"#if defined(PARAM_USE_PIXEL_ATOMICS)\n"
"#pragma OPENCL EXTENSION cl_khr_global_int32_base_atomics : enable\n"
"#endif\n"
"\n"
"#ifndef TRUE\n"
"#define TRUE 1\n"
"#endif\n"
"\n"
"#ifndef FALSE\n"
"#define FALSE 0\n"
"#endif\n"
"\n"
"#endif\n"
"\n"
"//------------------------------------------------------------------------------\n"
"// GPUTask data types\n"
"//------------------------------------------------------------------------------\n"
"\n"
"typedef enum {\n"
"	// Mega-kernel states\n"
"	RT_NEXT_VERTEX = 0,\n"
"	GENERATE_DL_RAY = 1,\n"
"	RT_DL = 2,\n"
"	GENERATE_NEXT_VERTEX_RAY = 3,\n"
"	SPLAT_SAMPLE = 4,\n"
"			\n"
"	// Micro-kernel states\n"
"	MK_RT_NEXT_VERTEX = 0, // Must have the same value of RT_NEXT_VERTEX\n"
"	MK_HIT_NOTHING = 1,\n"
"	MK_HIT_OBJECT = 2,\n"
"	MK_DL_ILLUMINATE = 3,\n"
"	MK_DL_SAMPLE_BSDF = 4,\n"
"	MK_RT_DL = 5,\n"
"	MK_GENERATE_NEXT_VERTEX_RAY = 6,\n"
"	MK_SPLAT_SAMPLE = 7,\n"
"	MK_NEXT_SAMPLE = 8,\n"
"	MK_GENERATE_CAMERA_RAY = 9\n"
"} PathState;\n"
"\n"
"typedef struct {\n"
"	unsigned int lightIndex;	\n"
"	float pickPdf;\n"
"\n"
"	Vector dir;\n"
"	float distance, directPdfW;\n"
"\n"
"	// Radiance to add to the result if light source is visible\n"
"	// Note: it doesn't include the pathThroughput\n"
"	Spectrum lightRadiance;\n"
"	// This is used only if PARAM_FILM_CHANNELS_HAS_IRRADIANCE is defined and\n"
"	// only for the first path vertex\n"
"	Spectrum lightIrradiance;\n"
"\n"
"	unsigned int lightID;\n"
"} DirectLightIlluminateInfo;\n"
"\n"
"// This is defined only under OpenCL because of variable size structures\n"
"#if defined(SLG_OPENCL_KERNEL)\n"
"\n"
"// The state used to keep track of the rendered path\n"
"typedef struct {\n"
"	PathState state;\n"
"	unsigned int pathVertexCount, noSpecularPathVertexCount;\n"
"\n"
"	Spectrum throughput;\n"
"	BSDF bsdf; // Variable size structure\n"
"} GPUTaskState;\n"
"\n"
"typedef struct {\n"
"	// Used to store some intermediate result\n"
"	DirectLightIlluminateInfo illumInfo;\n"
"\n"
"	BSDFEvent lastBSDFEvent;\n"
"	float lastPdfW;\n"
"\n"
"#if defined(PARAM_HAS_PASSTHROUGH)\n"
"	float rayPassThroughEvent;\n"
"#endif\n"
"} GPUTaskDirectLight;\n"
"\n"
"typedef struct {\n"
"	// The task seed\n"
"	Seed seed;\n"
"\n"
"	// Space for temporary storage\n"
"#if defined(PARAM_HAS_PASSTHROUGH) || defined(PARAM_HAS_VOLUMES)\n"
"	BSDF tmpBsdf; // Variable size structure\n"
"#endif\n"
"#if (PARAM_TRIANGLE_LIGHT_COUNT > 0) || defined(PARAM_HAS_VOLUMES)\n"
"	// This is used by TriangleLight_Illuminate() to temporary store the\n"
"	// point on the light sources.\n"
"	// Also used by Scene_Intersect() for evaluating volume textures.\n"
"	HitPoint tmpHitPoint;\n"
"#endif\n"
"} GPUTask;\n"
"\n"
"#endif\n"
"\n"
"typedef struct {\n"
"	unsigned int sampleCount;\n"
"} GPUTaskStats;\n"
; } }
