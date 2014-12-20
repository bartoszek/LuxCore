#line 2 "materialdefs_funcs_glossy2.cl"

/***************************************************************************
 * Copyright 1998-2013 by authors (see AUTHORS.txt)                        *
 *                                                                         *
 *   This file is part of LuxRender.                                       *
 *                                                                         *
 * Licensed under the Apache License, Version 2.0 (the "License");         *
 * you may not use this file except in compliance with the License.        *
 * You may obtain a copy of the License at                                 *
 *                                                                         *
 *     http://www.apache.org/licenses/LICENSE-2.0                          *
 *                                                                         *
 * Unless required by applicable law or agreed to in writing, software     *
 * distributed under the License is distributed on an "AS IS" BASIS,       *
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.*
 * See the License for the specific language governing permissions and     *
 * limitations under the License.                                          *
 ***************************************************************************/

//------------------------------------------------------------------------------
// GlossyTranslucent material
//
// LuxRender GlossyTranslucent material porting.
//------------------------------------------------------------------------------

#if defined (PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT)

BSDFEvent GlossyTranslucentMaterial_GetEventTypes() {
	return GLOSSY | DIFFUSE | REFLECT | TRANSMIT;
}

bool GlossyTranslucentMaterial_IsDelta() {
	return false;
}

#if defined(PARAM_HAS_PASSTHROUGH)
float3 GlossyTranslucentMaterial_GetPassThroughTransparency(__global Material *material,
		__global HitPoint *hitPoint, const float3 localFixedDir, const float passThroughEvent
		TEXTURES_PARAM_DECL) {
	return BLACK;
}
#endif

float SchlickBSDFGT_CoatingWeight(const float3 ks, const float3 fixedDir) {
	// Approximate H by using reflection direction for wi
	const float u = fabs(fixedDir.z);
	const float3 S = FresnelSchlick_Evaluate(ks, u);

	// Ensures coating is never sampled less than half the time
	// unless we are on the back face
	return .5f * (1.f + Spectrum_Filter(S));
}

float3 SchlickBSDFGT_CoatingF(const float3 ks, const float roughness,
		const float anisotropy, const int multibounce, const float3 fixedDir,
		const float3 sampledDir) {
	const float coso = fabs(fixedDir.z);
	const float cosi = fabs(sampledDir.z);

	const float3 wh = normalize(fixedDir + sampledDir);
	const float3 S = FresnelSchlick_Evaluate(ks, fabs(dot(sampledDir, wh)));

	const float G = SchlickDistribution_G(roughness, fixedDir, sampledDir);

	// Multibounce - alternative with interreflection in the coating creases
	float factor = SchlickDistribution_D(roughness, wh, anisotropy) * G;
	//if (!fromLight)
		factor = factor / 4.f * coso +
				(multibounce ? cosi * clamp((1.f - G) / (4.f * coso * cosi), 0.f, 1.f) : 0.f);
	//else
	//	factor = factor / (4.f * cosi) + 
	//			(multibounce ? coso * Clamp((1.f - G) / (4.f * cosi * coso), 0.f, 1.f) : 0.f);

	return factor * S;
}

float3 SchlickBSDFGT_CoatingSampleF(const float3 ks,
		const float roughness, const float anisotropy, const int multibounce,
		const float3 fixedDir, float3 *sampledDir,
		float u0, float u1, float *pdf) {
	float3 wh;
	float d, specPdf;
	SchlickDistribution_SampleH(roughness, anisotropy, u0, u1, &wh, &d, &specPdf);
	const float cosWH = dot(fixedDir, wh);
	*sampledDir = 2.f * cosWH * wh - fixedDir;

	if (((*sampledDir).z < DEFAULT_COS_EPSILON_STATIC) || (fixedDir.z * (*sampledDir).z < 0.f))
		return BLACK;

	const float coso = fabs(fixedDir.z);
	const float cosi = fabs((*sampledDir).z);

	*pdf = specPdf / (4.f * cosWH);
	if (*pdf <= 0.f)
		return BLACK;

	float3 S = FresnelSchlick_Evaluate(ks, fabs(cosWH));

	const float G = SchlickDistribution_G(roughness, fixedDir, *sampledDir);

	//CoatingF(sw, *wi, wo, f_);
	S *= (d / *pdf) * G / (4.f * coso) + 
			(multibounce ? cosi * clamp((1.f - G) / (4.f * coso * cosi), 0.f, 1.f) / *pdf : 0.f);

	return S;
}

float SchlickBSDFGT_CoatingPdf(const float roughness, const float anisotropy,
		const float3 fixedDir, const float3 sampledDir) {
	const float3 wh = normalize(fixedDir + sampledDir);
	return SchlickDistribution_Pdf(roughness, wh, anisotropy) / (4.f * fabs(dot(fixedDir, wh)));
}

float3 GlossyTranslucentMaterial_ConstEvaluate(
		__global HitPoint *hitPoint, const float3 lightDir, const float3 eyeDir,
		BSDFEvent *event, float *directPdfW,
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_INDEX)
		const float i, const float i_bf,
#endif
		const float nuVal, const float nuVal_bf,
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_ANISOTROPIC)
		const float nvVal, const float nvVal_bf,
#endif
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_ABSORPTION)
		const float3 kaVal, const float3 kaVal_bf,
		const float d, const float d_bf,
#endif
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_MULTIBOUNCE)
		const int multibounceVal, const int multibounceVal_bf,
#endif
		const float3 kdVal, const float3 ktVal, const float3 ksVal, const float3 ksVal_bf) {
	const float3 fixedDir = eyeDir;
	const float3 sampledDir = lightDir;

	const float cosi = fabs(sampledDir.z);
	const float coso = fabs(fixedDir.z);

	if (fixedDir.z * sampledDir.z <= 0.f) {
		// Transmition
		*event = DIFFUSE | TRANSMIT;

		if (directPdfW)
			*directPdfW = fabs(sampledDir.z) * M_1_PI_F * 0.5f;

		const float3 H = Normalize(float3(lightDir.x + eyeDir.x, lightDir.y + eyeDir.y,
			lightDir.z - eyeDir.z));
		const float u = fabs(dot(lightDir, H));
		float3 ks = ksVal;
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_INDEX)
		if (i > 0.f) {
			const float ti = (i - 1.f) / (i + 1.f);
			ks *= ti * ti;
		}
#endif
		ks = Spectrum_Clamp(ks);
		const float3 S1 = FresnelSchlick_Evaluate(ks, u);

		ks = ksVal_bf;
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_INDEX)
		if (i_bf > 0.f) {
			const float ti = (i_bf - 1.f) / (i_bf + 1.f);
			ks *= ti * ti;
		}
#endif
		ks = Spectrum_Clamp(ks);
		const float3 S2 = FresnelSchlick_Evaluate(ks, u);
		float3 S = Spectrum_Sqrt(WHITE - S1) * (WHITE - S2));
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_ABSORPTION)
		if (lightDir.z > 0.f) {
			S *= Spectrum_Exp(Spectrum_Clamp(kaVal) * -(d / cosi) +
				Spectrum_Clamp(kaVal_bf) * -(d_bf / coso));
		} else {
			S *= Spectrum_Exp(Spectrum_Clamp(kaVal) * -(d / coso) +
				Spectrum_Clamp(kaVal_bf) * -(d_bf / cosi));
		}
#endif
		return (M_1_PI_F * coso) * S * Spectrum_Clamp(ktVal) *
			(WHITE - Spectrum_Clamp(kdVal));
	} else {
		// Reflection
		*event = GLOSSY | REFLECT;

		const float3 baseF = Spectrum_Clamp(kdVal) * M_1_PI_F * cosi;
		float3 ks;
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_INDEX)
		float index;
#endif
		float u;
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_ANISOTROPIC)
		float v;
#endif
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_ABSORPTION)
		float3 alpha;
		float depth;
#endif
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_MULTIBOUNCE)
		int mbounce;
#else
		int mbounce = 0;
#endif
		if (eyeDir.z >= 0.f) {
			ks = ksVal;
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_INDEX)
			index = i;
#endif
			u = clamp(nuVal, 6e-3f, 1.f);
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_ANISOTROPIC)
			v = clamp(nvVal, 6e-3f, 1.f);
#endif
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_ABSORPTION)
			alpha = Spectrum_Clamp(kaVal);
			depth = d;
#endif
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_MULTIBOUNCE)
			mbounce = multibounceVal;
#endif
		} else {
			ks = ksVal_bf;
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_INDEX)
			index = i_bf;
#endif
			u = clamp(nuVal_bf, 6e-3f, 1.f);
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_ANISOTROPIC)
			v = clamp(nvVal_bf, 6e-3f, 1.f);
#endif
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_ABSORPTION)
			alpha = Spectrum_Clamp(kaVal_bf);
			depth = d_bf;
#endif
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_MULTIBOUNCE)
			mbounce = multibounceVal_bf;
#endif
		}

#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_INDEX)
		if (index > 0.f) {
			const float ti = (index - 1.f) / (index + 1.f);
			ks *= ti * ti;
		}
#endif
		ks = Spectrum_Clamp(ks);

#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_ANISOTROPIC)
		const float u2 = u * u;
		const float v2 = v * v;
		const float anisotropy = (u2 < v2) ? (1.f - u2 / v2) : (v2 / u2 - 1.f);
		const float roughness = u * v;
#else
		const float anisotropy = 0.f;
		const float roughness = u * u;
#endif

		if (directPdfW) {
			const float wCoating = SchlickBSDFGT_CoatingWeight(ks, fixedDir);
			const float wBase = 1.f - wCoating;

			*directPdfW = 0.5f * (wBase * fabsf(sampledDir.z * M_1_PI_F) +
				wCoating * SchlickBSDFGT_CoatingPdf(roughness, anisotropy, fixedDir, sampledDir));
		}

		// Absorption
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_ABSORPTION)
		const float3 absorption = CoatingAbsorption(cosi, coso, alpha, depth);
#else
		const float3 absorption = WHITE;
#endif

		// Coating fresnel factor
		const float3 H = Normalize(fixedDir + sampledDir);
		const float3 S = FresnelSchlick_Evaluate(ks, fabs(dot(sampledDir, H)));

		const float3 coatingF = SchlickBSDFGT_CoatingF(ks, roughness, anisotropy, mbounce, fixedDir, sampledDir);

		// Blend in base layer Schlick style
		// assumes coating bxdf takes fresnel factor S into account

		return coatingF + absorption * (WHITE - S) * baseF;
	}
}

float3 GlossyTranslucentMaterial_ConstSample(
		__global HitPoint *hitPoint, const float3 fixedDir, float3 *sampledDir,
		const float u0, const float u1,
#if defined(PARAM_HAS_PASSTHROUGH)
		const float passThroughEvent,
#endif
		float *pdfW, float *cosSampledDir, BSDFEvent *event,
		const BSDFEvent requestedEvent,
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_INDEX)
		const float i, const float i_bf,
#endif
		const float nuVal, const float nuVal_bf,
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_ANISOTROPIC)
		const float nvVal, const float nvVal_bf,
#endif
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_ABSORPTION)
		const float3 kaVal, const float3 kaVal_bf,
		const float d, const float d_bf,
#endif
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_MULTIBOUNCE)
		const int multibounceVal, const int multibounceVal_bf,
#endif
		const float3 kdVal, const float3 ktVal, const float3 ksVal, const float3 ksVal_bf) {
	if (!(requestedEvent & (GLOSSY | REFLECT)) || !(requestedEvent & (DIFFUSE | TRANSMIT)) ||
		(fabs(fixedDir.z) < DEFAULT_COS_EPSILON_STATIC))
		return BLACK;

	if (passThroughEvent < 0.5f) {
		// Reflection
		float3 ks;
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_INDEX)
		float index;
#endif
		float u;
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_ANISOTROPIC)
		float v;
#endif
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_ABSORPTION)
		float3 alpha;
		float depth;
#endif
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_MULTIBOUNCE)
		int mbounce;
#else
		int mbounce = 0;
#endif
		if (fixedDir.z >= 0.f) {
			ks = ksVal;
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_INDEX)
			index = i;
#endif
			u = clamp(nuVal, 6e-3f, 1.f);
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_ANISOTROPIC)
			v = clamp(nvVal, 6e-3f, 1.f);
#endif
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_ABSORPTION)
			alpha = Spectrum_Clamp(kaVal);
			depth = d;
#endif
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_MULTIBOUNCE)
			mbounce = multibounceVal;
#endif
		} else {
			ks = ksVal_bf;
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_INDEX)
			index = i_bf;
#endif
			u = clamp(nuVal_bf, 6e-3f, 1.f);
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_ANISOTROPIC)
			v = clamp(nvVal_bf, 6e-3f, 1.f);
#endif
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_ABSORPTION)
			alpha = Spectrum_Clamp(kaVal_bf);
			depth = d_bf;
#endif
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_MULTIBOUNCE)
			mbounce = multibounceVal_bf;
#endif
		}

#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_INDEX)
		if (index > 0.f) {
			const float ti = (index - 1.f) / (index + 1.f);
			ks *= ti * ti;
		}
#endif
		ks = Spectrum_Clamp(ks);

#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_ANISOTROPIC)
		const float u2 = u * u;
		const float v2 = v * v;
		const float anisotropy = (u2 < v2) ? (1.f - u2 / v2) : (v2 / u2 - 1.f);
		const float roughness = u * v;
#else
		const float anisotropy = 0.f;
		const float roughness = u * u;
#endif

		const float wCoating = SchlickBSDFGT_CoatingWeight(ks, fixedDir);
		const float wBase = 1.f - wCoating;

		float basePdf, coatingPdf;
		float3 baseF, coatingF;

		if (2.f * passThroughEvent < wBase) {
			// Sample base BSDF (Matte BSDF)
			*sampledDir = signbit(fixedDir.z) * CosineSampleHemisphere(u0, u1, &basePdf);

			*cosSampledDir = fabs((*sampledDir).z);
			if (*cosSampledDir < DEFAULT_COS_EPSILON_STATIC)
				return BLACK;

			baseF = Spectrum_Clamp(kdVal) * M_1_PI_F * *cosSampledDir;

			// Evaluate coating BSDF (Schlick BSDF)
			coatingF = SchlickBSDFGT_CoatingF(ks, roughness, anisotropy, mbounce,
				fixedDir, *sampledDir);
			coatingPdf = SchlickBSDFGT_CoatingPdf(roughness, anisotropy, fixedDir, *sampledDir);

			*event = GLOSSY | REFLECT;
		} else {
			// Sample coating BSDF (Schlick BSDF)
			coatingF = SchlickBSDFGT_CoatingSampleF(ks, roughness, anisotropy, mbounce,
				fixedDir, sampledDir, u0, u1, &coatingPdf);
			if (Spectrum_IsBlack(coatingF))
				return BLACK;

			*cosSampledDir = fabs((*sampledDir).z);
			if (*cosSampledDir < DEFAULT_COS_EPSILON_STATIC)
				return BLACK;

			coatingF *= coatingPdf;

			// Evaluate base BSDF (Matte BSDF)
			basePdf = *cosSampledDir * M_1_PI_F;
			baseF = Spectrum_Clamp(kdVal) * M_1_PI_F * *cosSampledDir;

			*event = GLOSSY | REFLECT;
		}

		*pdfW = coatingPdf * wCoating + basePdf * wBase;

		// Absorption
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_ABSORPTION)
		const float cosi = fabs((*sampledDir).z);
		const float coso = fabs(fixedDir.z);
		const float3 absorption = CoatingAbsorption(cosi, coso, alpha, d);
#else
		const float3 absorption = WHITE;
#endif

		// Coating fresnel factor
		const float3 H = Normalize(fixedDir + *sampledDir);
		const float3 S = FresnelSchlick_Evaluate(ks, fabs(dot(*sampledDir, H)));

		// Blend in base layer Schlick style
		// coatingF already takes fresnel factor S into account

		return (coatingF + absorption * (WHITE - S) * baseF) / *pdfW;
	} else {
		// Transmition
		*sampledDir = -signbit(fixedDir.z) * CosineSampleHemisphere(u0, u1, pdfW);
		*pdfW *= 0.5f;

		*cosSampledDir = fabs((*sampledDir).z);
		if (*cosSampledDir < DEFAULT_COS_EPSILON_STATIC)
			return BLACK;

		*event = DIFFUSE | TRANSMIT;

		const float cosi = fabs((*sampledDir).z);
		const float coso = fabs(fixedDir.z);

		if (directPdfW)
			*directPdfW = fabs((*sampledDir).z) * M_1_PI_F * 0.5f;

		const float3 H = Normalize(float3((*sampledDir).x + fixedDir.x, (*sampledDir).y + fixedDir.y,
			(*sampledDir).z - fixedDir.z));
		const float u = fabs(dot(*sampledDir, H));
		float3 ks = ksVal;
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_INDEX)
		if (i > 0.f) {
			const float ti = (i - 1.f) / (i + 1.f);
			ks *= ti * ti;
		}
#endif
		ks = Spectrum_Clamp(ks);
		const float3 S1 = FresnelSchlick_Evaluate(ks, u);

		ks = ksVal_bf;
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_INDEX)
		if (i_bf > 0.f) {
			const float ti = (i_bf - 1.f) / (i_bf + 1.f);
			ks *= ti * ti;
		}
#endif
		ks = Spectrum_Clamp(ks);
		const float3 S2 = FresnelSchlick_Evaluate(ks, u);
		float3 S = Spectrum_Sqrt(WHITE - S1) * (WHITE - S2));
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_ABSORPTION)
		if ((*sampledDir).z > 0.f) {
			S *= Spectrum_Exp(Spectrum_Clamp(kaVal) * -(d / cosi) +
				Spectrum_Clamp(kaVal_bf) * -(d_bf / coso));
		} else {
			S *= Spectrum_Exp(Spectrum_Clamp(kaVal) * -(d / coso) +
				Spectrum_Clamp(kaVal_bf) * -(d_bf / cosi));
		}
#endif
		return (M_1_PI_F * coso) * S * Spectrum_Clamp(ktVal) *
			(WHITE - Spectrum_Clamp(kdVal));
	}
}

#if defined(PARAM_DISABLE_MAT_DYNAMIC_EVALUATION)
float3 GlossyTranslucentMaterial_Evaluate(__global Material *material,
		__global HitPoint *hitPoint, const float3 lightDir, const float3 eyeDir,
		BSDFEvent *event, float *directPdfW
		TEXTURES_PARAM_DECL) {
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_INDEX)
	const float i = Texture_GetFloatValue(material->glossytranslucent.indexTexIndex, hitPoint
			TEXTURES_PARAM);
	const float i_bf = Texture_GetFloatValue(material->glossytranslucent.indexbfTexIndex, hitPoint
			TEXTURES_PARAM);
#endif

	const float nuVal = Texture_GetFloatValue(material->glossytranslucent.nuTexIndex, hitPoint
		TEXTURES_PARAM);
	const float nuVal_bf = Texture_GetFloatValue(material->glossytranslucent.nubfTexIndex, hitPoint
		TEXTURES_PARAM);
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_ANISOTROPIC)
	const float nvVal = Texture_GetFloatValue(material->glossytranslucent.nvTexIndex, hitPoint
		TEXTURES_PARAM);
	const float nvVal_bf = Texture_GetFloatValue(material->glossytranslucent.nvbfTexIndex, hitPoint
		TEXTURES_PARAM);
#endif

#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_ABSORPTION)
	const float3 kaVal = Texture_GetSpectrumValue(material->glossytranslucent.kaTexIndex, hitPoint
			TEXTURES_PARAM);
	const float d = Texture_GetFloatValue(material->glossytranslucent.depthTexIndex, hitPoint
			TEXTURES_PARAM);
	const float3 kaVal_bf = Texture_GetSpectrumValue(material->glossytranslucent.kabfTexIndex, hitPoint
			TEXTURES_PARAM);
	const float d_bf = Texture_GetFloatValue(material->glossytranslucent.depthbfTexIndex, hitPoint
			TEXTURES_PARAM);
#endif

#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_MULTIBOUNCE)
	const int multibounce = material->glossytranslucent.multibounce;
	const int multibounce_bf = material->glossytranslucent.multibouncebf;
#endif

	const float3 kdVal = Texture_GetSpectrumValue(material->glossytranslucent.kdTexIndex, hitPoint
			TEXTURES_PARAM);
	const float3 ktVal = Texture_GetSpectrumValue(material->glossytranslucent.ktTexIndex, hitPoint
			TEXTURES_PARAM);
	const float3 ksVal = Texture_GetSpectrumValue(material->glossytranslucent.ksTexIndex, hitPoint
			TEXTURES_PARAM);
	const float3 ksVal_bf = Texture_GetSpectrumValue(material->glossytranslucent.ksbfTexIndex, hitPoint
			TEXTURES_PARAM);

	return GlossyTranslucentMaterial_ConstEvaluate(
			hitPoint, lightDir, eyeDir,
			event, directPdfW,
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_INDEX)
			i, i_bf,
#endif
			nuVal, nuVal_bf,
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_ANISOTROPIC)
			nvVal, nvVal_bf,
#endif
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_ABSORPTION)
			kaVal, kaVal_bf,
			d, d_bf,
#endif
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_MULTIBOUNCE)
			multibounce, multibounce_bf,
#endif
			kdVal, ktVal, ksVal, ksVal_bf);
}

float3 GlossyTranslucentMaterial_Sample(__global Material *material,
		__global HitPoint *hitPoint, const float3 fixedDir, float3 *sampledDir,
		const float u0, const float u1,
#if defined(PARAM_HAS_PASSTHROUGH)
		const float passThroughEvent,
#endif
		float *pdfW, float *cosSampledDir, BSDFEvent *event,
		const BSDFEvent requestedEvent
		TEXTURES_PARAM_DECL) {
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_INDEX)
	const float i = Texture_GetFloatValue(material->glossytranslucent.indexTexIndex, hitPoint
			TEXTURES_PARAM);
	const float i_bf = Texture_GetFloatValue(material->glossytranslucent.indexbfTexIndex, hitPoint
			TEXTURES_PARAM);
#endif

	const float nuVal = Texture_GetFloatValue(material->glossytranslucent.nuTexIndex, hitPoint
		TEXTURES_PARAM);
	const float nuVal_bf = Texture_GetFloatValue(material->glossytranslucent.nubfTexIndex, hitPoint
		TEXTURES_PARAM);
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_ANISOTROPIC)
	const float nvVal = Texture_GetFloatValue(material->glossytranslucent.nvTexIndex, hitPoint
		TEXTURES_PARAM);
	const float nvVal_bf = Texture_GetFloatValue(material->glossytranslucent.nvbfTexIndex, hitPoint
		TEXTURES_PARAM);
#endif

#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_ABSORPTION)
	const float3 kaVal = Texture_GetSpectrumValue(material->glossytranslucent.kaTexIndex, hitPoint
			TEXTURES_PARAM);
	const float d = Texture_GetFloatValue(material->glossytranslucent.depthTexIndex, hitPoint
			TEXTURES_PARAM);
	const float3 kaVal_bf = Texture_GetSpectrumValue(material->glossytranslucent.kabfTexIndex, hitPoint
			TEXTURES_PARAM);
	const float d_bf = Texture_GetFloatValue(material->glossytranslucent.depthbfTexIndex, hitPoint
			TEXTURES_PARAM);
#endif

#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_MULTIBOUNCE)
	const int multibounce = material->glossytranslucent.multibounce;
	const int multibounce_bf = material->glossytranslucent.multibouncebf;
#endif

	const float3 kdVal = Texture_GetSpectrumValue(material->glossytranslucent.kdTexIndex, hitPoint
			TEXTURES_PARAM);
	const float3 ktVal = Texture_GetSpectrumValue(material->glossytranslucent.ktTexIndex, hitPoint
			TEXTURES_PARAM);
	const float3 ksVal = Texture_GetSpectrumValue(material->glossytranslucent.ksTexIndex, hitPoint
			TEXTURES_PARAM);
	const float3 ksVal_bf = Texture_GetSpectrumValue(material->glossytranslucent.ksbfTexIndex, hitPoint
			TEXTURES_PARAM);

	return GlossyTranslucentMaterial_ConstSample(
			hitPoint, fixedDir, sampledDir,
			u0, u1,
#if defined(PARAM_HAS_PASSTHROUGH)
			passThroughEvent,
#endif
			pdfW, cosSampledDir, event,
			requestedEvent,
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_INDEX)
			i, i_bf,
#endif
			nuVal, nuVal_bf,
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_ANISOTROPIC)
			nvVal, nvVal_bf,
#endif
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_ABSORPTION)
			kaVal, kaVal_bf,
			d, d_bf,
#endif
#if defined(PARAM_ENABLE_MAT_GLOSSYTRANSLUCENT_MULTIBOUNCE)
			multibounce, multibounce_bf,
#endif
			kdVal, ktVal, ksVal, ksVal_bf);
}
#endif

#endif
