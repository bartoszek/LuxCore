/***************************************************************************
 * Copyright 1998-2015 by authors (see AUTHORS.txt)                        *
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

#ifndef _SLG_MAPPING_H
#define	_SLG_MAPPING_H

#include <string>

#include "luxrays/luxrays.h"
#include "luxrays/core/geometry/uv.h"
#include "luxrays/core/geometry/transform.h"
#include "slg/slg.h"
#include "slg/bsdf/hitpoint.h"

namespace slg {

// OpenCL data types
namespace ocl {
using namespace luxrays::ocl;
#include "slg/textures/mapping/mapping_types.cl"
}

typedef enum {
	UVMAPPING2D
} TextureMapping2DType;

class TextureMapping2D {
public:
	TextureMapping2D() { }
	virtual ~TextureMapping2D() { }

	virtual TextureMapping2DType GetType() const = 0;

	virtual luxrays::UV Map(const HitPoint &hitPoint) const {
		return Map(hitPoint.uv);
	}
	// Directly used only in InfiniteLight and ImageMapTexture
	virtual luxrays::UV Map(const luxrays::UV &uv) const = 0;

	virtual luxrays::Properties ToProperties(const std::string &name) const = 0;
};

typedef enum {
	UVMAPPING3D, GLOBALMAPPING3D
} TextureMapping3DType;

class TextureMapping3D {
public:
	TextureMapping3D(const luxrays::Transform &w2l) : worldToLocal(w2l) { }
	virtual ~TextureMapping3D() { }

	virtual TextureMapping3DType GetType() const = 0;

	virtual luxrays::Point Map(const HitPoint &hitPoint) const = 0;

	virtual luxrays::Properties ToProperties(const std::string &name) const = 0;

	luxrays::Transform worldToLocal;
};

//------------------------------------------------------------------------------
// UVMapping2D
//------------------------------------------------------------------------------

class UVMapping2D : public TextureMapping2D {
public:
	UVMapping2D(const float uscale, const float vscale,
			const float udelta, const float vdelta) : uScale(uscale),
			vScale(vscale), uDelta(udelta), vDelta(vdelta) { }
	virtual ~UVMapping2D() { }

	virtual TextureMapping2DType GetType() const { return UVMAPPING2D; }

	virtual luxrays::UV Map(const luxrays::UV &uv) const {
		return luxrays::UV(uv.u * uScale + uDelta, uv.v * vScale + vDelta);
	}

	virtual luxrays::Properties ToProperties(const std::string &name) const {
		luxrays::Properties props;
		props.Set(luxrays::Property(name + ".type")("uvmapping2d"));
		props.Set(luxrays::Property(name + ".uvscale")(uScale, vScale));
		props.Set(luxrays::Property(name + ".uvdelta")(uDelta, vDelta));

		return props;
	}

	float uScale, vScale, uDelta, vDelta;
};

//------------------------------------------------------------------------------
// UVMapping3D
//------------------------------------------------------------------------------

class UVMapping3D : public TextureMapping3D {
public:
	UVMapping3D(const luxrays::Transform &w2l) : TextureMapping3D(w2l) { }
	virtual ~UVMapping3D() { }

	virtual TextureMapping3DType GetType() const { return UVMAPPING3D; }

	virtual luxrays::Point Map(const HitPoint &hitPoint) const {
		return worldToLocal * luxrays::Point(hitPoint.uv.u, hitPoint.uv.v, 0.f);
	}

	virtual luxrays::Properties ToProperties(const std::string &name) const {
		luxrays::Properties props;
		props.Set(luxrays::Property(name + ".type")("uvmapping3d"));
		props.Set(luxrays::Property(name + ".transformation")(worldToLocal.mInv));

		return props;
	}
};

//------------------------------------------------------------------------------
// GlobalMapping3D
//------------------------------------------------------------------------------

class GlobalMapping3D : public TextureMapping3D {
public:
	GlobalMapping3D(const luxrays::Transform &w2l) : TextureMapping3D(w2l) { }
	virtual ~GlobalMapping3D() { }

	virtual TextureMapping3DType GetType() const { return GLOBALMAPPING3D; }

	virtual luxrays::Point Map(const HitPoint &hitPoint) const {
		return worldToLocal * hitPoint.p;
	}

	virtual luxrays::Properties ToProperties(const std::string &name) const {
		luxrays::Properties props;
		props.Set(luxrays::Property(name + ".type")("globalmapping3d"));
		props.Set(luxrays::Property(name + ".transformation")(worldToLocal.mInv));

		return props;
	}
};

}

#endif	/* _SLG_MAPPING_H */
