import std.random;
debug {import std.stdio;
import std.math.rounding;}

struct Vec2i {
	int x, y;
}

enum MaterialType {
	air,
	solid,
	powder,
	liquid,
	gas
}

enum InteractionType {
	burn,
	changeSelf,
	changeEnother,
	changeBoth,
	explode
}

struct InteractionRule
{
	InteractionType type;
	Material* material;
	float spreadFactor = 0.5f;

}

struct FlammabilityRule
{
	float flammability = 0.0f;
	float fireRate = 0.3f;
	Material* burningMaterial;
	bool isBurning = false;
}

struct Material {
	ushort id;
	MaterialType type;
	float density;
	int[] colors;
	InteractionRule[ushort] interactions;
	FlammabilityRule flammabilityRule;
}

struct Pixel {
	Material* material;
	ubyte color;
	ubyte updateCounter;
	bool colorOverriden;
	int colorOverride;

	int getColor() {
		if (!colorOverriden)
			return material.colors[color];
		else
			return color;
	}

	void resetColor() {
		color = cast(ubyte) uniform(0, material.colors.length);
	}
}

struct PixelWithVelocity {
	Pixel pixel;
	float x, y, velX, velY;
}

void swapPixels(Pixel* p1, Pixel* p2) {
	Pixel buf = *p1;
	*p1 = *p2;
	*p2 = buf;
}

bool tryMovePixel(Pixel* from, Pixel* to, ubyte step, bool diffuse = false) {
	if (to is null)
		return false;
	if (to.material.type == MaterialType.air) {
		auto air = to.material;
		*to = *from;
		*from = Pixel(air, 0, 0, false, 0);
		to.updateCounter = step;
		return true;
	}
	if (to.material.density < from.material.density || (diffuse && to.material.density == from.material.density)) {
		swapPixels(to, from);
		to.updateCounter = step;
		return true;
	}
	return false;
}

bool tryMovePixelRecursive(
	Chunk* chunk,
	Pixel* from, int fromX, int fromY,
	Pixel* to, int toX, int toY,
	ubyte step, bool diffuse = false
) {
	if (to is null)
		return false;
	// if (to.material == from.material && to.updateCounter != step) {
	// 	int beyondX = toX * 2 - fromX;
	// 	int beyondY = toY * 2 - fromY;
	// 	Pixel* pixelBeyond = chunk.getPixel(beyondX, beyondY);
	// 	if (pixelBeyond is null || pixelBeyond.updateCounter == step)
	// 		return false;
	// 	// writefln("%s moves %s", fromX, toX);
	// 	if (!tryMovePixelRecursive(chunk, to, toX, toY,
	// 		pixelBeyond, beyondX, beyondY, step))
	// 	return false;
	// }
	if (to.material.type == MaterialType.air) {
		auto air = to.material;
		*to = *from;
		*from = Pixel(air, 0, step, false, 0);
		to.updateCounter = step;
		return true;
	}
	if (to.material.density <= from.material.density) {
		int beyondX = toX * 2 - fromX;
		int beyondY = toY * 2 - fromY;
		Pixel* pixelBeyond = chunk.getPixel(beyondX, beyondY);
		if (pixelBeyond is null || pixelBeyond.updateCounter == step)
			return false;
		// writefln("%s moves %s", fromX, toX);
			// from.updateCounter = step;
		if (tryMovePixelRecursive(chunk, to, toX, toY,
			pixelBeyond, beyondX, beyondY, step)
		) {
			return true;
		}
	}
	// if (to.material.density < from.material.density || (diffuse && to.material.density == from.material.density)) {
	// 	swapPixels(to, from);
	// 	to.updateCounter = step;
	// 	return true;
	// }
	
	return false;
}

void throwPixel(World* world, Pixel* pixel, float x, float y, float velX, float velY) {
	world.pixelsWithVelocity ~= PixelWithVelocity(*pixel, x, y, velX, velY);
	*pixel = Pixel(&world.materials[0], 0, 0, false, 0);
}

enum chunkSize = 64;
enum chunkArea = chunkSize * chunkSize;

struct Chunk {
	World* world;
	int x, y;
	Chunk* left, right; /// Nearest chunks on sides. Can be not neighbors
	Pixel[chunkArea] pixels;

	void step(ubyte step) {
		bool reverse = step % 2 == 1;
		// bool reverse = false;
		auto rand = Random(step + x + y * 3);
		int i = reverse ? chunkSize - 1 : 0;
		for (;;) {
			pixelStep(i, step);
			if (reverse) {
				if (i == chunkArea - chunkSize)
					break;
				if (i % chunkSize == 0)
					i += chunkSize * 2 - 1;
				else
					i--;
			} else {
				i++;
				if (i == chunkArea)
					break;
			}	
		}
	}

	void pixelStep(int index, ubyte step) {
		Pixel* pixel = &pixels[index];

		if (pixel.material.interactions.length){
				int px = this.x * chunkSize + index % chunkSize;
				int py = this.y * chunkSize + index / chunkSize;
				Pixel*[] surroundingPxs = [
					getPixel(px, py - 1),//under
					// getPixel(px - 1, py - 1),//underLeft
					// getPixel(px + 1, py - 1),//underRightI
					getPixel(px - 1, py),//leftPx
					getPixel(px + 1, py),//rightPx
					getPixel(px, py + 1),//above
					// getPixel(px - 1, py + 1),//aboveLeft
					// getPixel(px + 1, py + 1),//aboveRight
					];

				foreach (i, pix; surroundingPxs) {
					if (pix !is null && pix.material.id in pixel.material.interactions && pix.updateCounter != step) {
						InteractionRule interaction = pixel.material.interactions[pix.material.id];
						
						switch (interaction.type){
							case InteractionType.burn://burn
								// if (uniform(0.0f, 1.0f) < pix.material.flammabilityRule.flammability)
								// 	changeMaterial(pix, pix.material.flammabilityRule.burningMaterial);
								// if(uniform(0.0f, 1.0f) < ) Пока не работает...я устав

								break;
							case InteractionType.changeSelf://changeself
								changeMaterial(pixel, interaction.material);
								break;
							case InteractionType.changeEnother://changeEnother
								if (uniform(0.0f, 1.0f) < interaction.spreadFactor)
									changeMaterial(pix, interaction.material);
								break;
							case InteractionType.changeBoth://changeBoth
								changeMaterial(pix, interaction.material);
								changeMaterial(pixel, interaction.material);
								break;
							case InteractionType.explode://explode
								break;
							default:
								break;
						}

					}
    			}
			}

		if (pixel.updateCounter != step) {
			int px = this.x * chunkSize + index % chunkSize;
			int py = this.y * chunkSize + index / chunkSize;
			auto thisMat = pixel.material;
			final switch (thisMat.type) {
			case MaterialType.air, MaterialType.solid: break;
			case MaterialType.powder: {
				Pixel* under = getPixel(px, py - 1);
				if (tryMovePixel(pixel, under, step))
					break;
				Pixel* underLeft = getPixel(px - 1, py - 1);
				Pixel* underRight = getPixel(px + 1, py - 1);
				if (uniform(0, 2) == 0) {
					if (tryMovePixel(pixel, underLeft, step))
						break;
					if (tryMovePixel(pixel, underRight, step))
						break;
				} else {
					if (tryMovePixel(pixel, underRight, step))
						break;
					if (tryMovePixel(pixel, underLeft, step))
						break;
				}
				break;
			}
			case MaterialType.liquid: {
				enum fallBoostMultiplier = 1.5;
				Pixel* under = getPixel(px, py - 1);
				if (tryMovePixel(pixel, under, step)) {
					pixel = under;
					under = getPixel(px, py - 2);
					if (under !is null && under.material.type == MaterialType.air)
						throwPixel(world, pixel, px, py - 1, (uniform01() - 0.5) * world.targetPhyxelTps * 0.4,  -world.targetPhyxelTps * fallBoostMultiplier);
					break;
				}
				Pixel* underLeft = getPixel(px - 1, py - 1);
				Pixel* underRight = getPixel(px + 1, py - 1);
				version (noSplat) {
					if (uniform(0, 2) == 0) {
						if (tryMovePixel(pixel, underLeft, step))
							break;
						if (tryMovePixel(pixel, underRight, step))
							break;
					} else {
						if (tryMovePixel(pixel, underRight, step))
							break;
						if (tryMovePixel(pixel, underLeft, step))
							break;
					}
				} else {
					if (uniform(0, 2) == 0) {
						if (tryMovePixel(pixel, underLeft, step)) {
							Pixel* lowerLeft = getPixel(px - 1, py - 2);
							if (lowerLeft !is null && lowerLeft.material.type == MaterialType.air) {
								float offset = uniform01() * world.targetPhyxelTps;
								throwPixel(world, underLeft, px - 1, py, -offset, -world.targetPhyxelTps * fallBoostMultiplier);
							}
							break;
						}
						if (tryMovePixel(pixel, underRight, step)) {
							Pixel* lowerRight = getPixel(px + 1, py - 2);
							if (lowerRight !is null && lowerRight.material.type == MaterialType.air) {
								float offset = uniform01() * world.targetPhyxelTps;
								throwPixel(world, underRight, px + 1, py, offset, -world.targetPhyxelTps * fallBoostMultiplier);
							}
							break;
						}
					} else {
						if (tryMovePixel(pixel, underRight, step)) {
							Pixel* lowerRight = getPixel(px + 1, py - 2);
							if (lowerRight !is null && lowerRight.material.type == MaterialType.air) {
								float offset = uniform01() * world.targetPhyxelTps;
								throwPixel(world, underRight, px + 1, py, offset, -world.targetPhyxelTps * fallBoostMultiplier);
							}
							break;
						}
						if (tryMovePixel(pixel, underLeft, step)) {
							Pixel* lowerLeft = getPixel(px - 1, py - 2);
							if (lowerLeft !is null && lowerLeft.material.type == MaterialType.air) {
								float offset = uniform01() * world.targetPhyxelTps;
								throwPixel(world, underLeft, px - 1, py, -offset, -world.targetPhyxelTps * fallBoostMultiplier);
							}
							break;
						}
					}
					
				}
				Pixel* leftPx = getPixel(px - 1, py);
				Pixel* rightPx = getPixel(px + 1, py);
				ubyte moveDist = 4;
				if (uniform(0, 2) == 0) {
					while (tryMovePixel(pixel, leftPx, step) && moveDist > 0) {
						moveDist -= 1;
						px -= 1;
						pixel = leftPx;
						leftPx = getPixel(px - 1, py);
						under = getPixel(px - 1, py - 1);
						if (under is null || under.material.type != MaterialType.liquid)
							break;
					}
					break;
				} else {
					while (tryMovePixel(pixel, rightPx, step) && moveDist > 0) {
						moveDist -= 1;
						px += 1;
						pixel = rightPx;
						rightPx = getPixel(px + 1, py);
						under = getPixel(px + 1, py - 1);
						if (under is null || under.material.type != MaterialType.liquid)
							break;
					}
					break;
				}
				break;
			}
			case MaterialType.gas: {
				Pixel* above = getPixel(px, py + 1);
				if (tryMovePixel(pixel, above, step))
					break;
				Pixel* aboveLeft = getPixel(px - 1, py + 1);
				Pixel* aboveRight = getPixel(px + 1, py + 1);
				if (uniform(0, 2) == 0) {
					if (tryMovePixel(pixel, aboveLeft, step))
						break;
					if (tryMovePixel(pixel, aboveRight, step))
						break;
				} else {
					if (tryMovePixel(pixel, aboveRight, step))
						break;
					if (tryMovePixel(pixel, aboveLeft, step))
						break;
				}
				Pixel* leftPx = getPixel(px - 1, py);
				Pixel* rightPx = getPixel(px + 1, py);
				if (uniform(0, 2) == 0) {
					if (tryMovePixel(pixel, leftPx, step))
						break;
					if (tryMovePixel(pixel, rightPx, step))
						break;
				} else {
					if (tryMovePixel(pixel, rightPx, step))
						break;
					if (tryMovePixel(pixel, leftPx, step))
						break;
				}
				break;
			}
			} 
		}
	}

	Pixel* getPixel(int x, int y) {
		int cx = this.x * chunkSize;
		int cy = this.y * chunkSize;
		if (x < cx) {
			auto other = Vec2i(this.x - 1, this.y) in world.chunks;
			if (other !is null)
				return (*other).getPixel(x, y);
			else
				return null;
		} else if (x >= cx + chunkSize) {
			auto other = Vec2i(this.x + 1, this.y) in world.chunks;
			if (other !is null)
				return (*other).getPixel(x, y);
			else
				return null;
		} else if (y < cy) {
			auto other = Vec2i(this.x, this.y - 1) in world.chunks;
			if (other !is null)
				return (*other).getPixel(x, y);
			else
				return null;
		} else if (y >= cy + chunkSize) {
			auto other = Vec2i(this.x, this.y + 1) in world.chunks;
			if (other !is null)
				return (*other).getPixel(x, y);
			else
				return null;
		} else {
			return &pixels[x - cx + (y - cy) * chunkSize];
		}
	}
}

struct ChunkRow {
	Chunk* leftmost;
	ChunkRow* above;
}

struct World {
	Material[] materials;
	Chunk*[Vec2i] chunks;
	ChunkRow* lowestRow;
	ubyte stepCounter;
	float targetPhyxelTps = 20;
    float phyxelDt = 0;

	float gravity = 2;
	PixelWithVelocity[] pixelsWithVelocity;

	void step(float dt) {
		phyxelDt += dt;
		if (phyxelDt >= 1 / targetPhyxelTps) {
			bool reverse = stepCounter % 2 == 0;
			ChunkRow* row = lowestRow;
			while (row !is null) {
				Chunk*[] line;
				Chunk* chunk = row.leftmost;
				while (chunk !is null) {
					line ~= chunk;
					chunk = chunk.right;
				}
				ushort y = 0;
				while (y < chunkSize) {
					if (reverse) {
						foreach_reverse (Chunk* lineChunk; line) {
							int i = (y + 1) * chunkSize - 1;
							auto c = chunkSize;
							while (c != 0) {
								lineChunk.pixelStep(i, stepCounter);
								i--;
								c--;
							}
						}
					} else {
						foreach (Chunk* lineChunk; line) {
							int i = y * chunkSize;
							auto c = chunkSize;
							while (c != 0) {
								lineChunk.pixelStep(i, stepCounter);
								i++;
								c--;
							}
						}
					}
					y++;
				}
				row = row.above;
			}
			foreach (i, ref pixel; pixelsWithVelocity) {
				pixel.velY -= gravity;
				float newX = pixel.x + pixel.velX * dt;
				float newY = pixel.y + pixel.velY * dt;
				auto targetPx = getPixel(cast(int) round(newX), cast(int) round(newY));
				if (targetPx is null || targetPx.material.type != MaterialType.air) {
					int x = cast(int) round(pixel.x);
					int y = cast(int) round(pixel.y);
					targetPx = getPixel(x, y);
					while (targetPx !is null && targetPx.material.type != MaterialType.air) {
						y += 1;
						targetPx = getPixel(x, y);
					}
					if (targetPx !is null)
						*targetPx = pixel.pixel;
					if (i + 1 < pixelsWithVelocity.length)
						pixelsWithVelocity[i] = pixelsWithVelocity[$ - 1];
					pixelsWithVelocity.length -= 1;
				} else {
					pixel.x = newX;
					pixel.y = newY;
				}
			}
			stepCounter++;
			phyxelDt = 0;
		}
	}

	void addChunk(Chunk* newChunk) {
		newChunk.world = &this;
		chunks[Vec2i(newChunk.x, newChunk.y)] = newChunk;

		if (lowestRow is null) {
			lowestRow = new ChunkRow();
			lowestRow.leftmost = newChunk;
			return;
		}

		ChunkRow** rowPtr = &lowestRow;
		while (*rowPtr !is null) {
			auto row = *rowPtr;
			if (row.leftmost.y == newChunk.y) {
				if (row.leftmost.x > newChunk.x) {
					newChunk.right = row.leftmost;
					row.leftmost.left = newChunk;
					row.leftmost = newChunk;
					return;
				} else {
					Chunk* ch = row.leftmost;
					while (ch.right !is null && ch.right.x < newChunk.x) {
						ch = ch.right;
					}
					if (ch.right !is null)
						ch.right.left = newChunk;
					newChunk.right = ch.right;
					ch.right = newChunk;
					newChunk.left = ch;
					return;
				}
			} else if (newChunk.y < row.leftmost.y) {
				auto newRow = new ChunkRow();
				newRow.leftmost = newChunk;
				newRow.above = row;
				*rowPtr = newRow;
				return;
			} else if (row.above is null) {
				auto newRow = new ChunkRow();
				newRow.leftmost = newChunk;
				row.above = newRow;
				return;
			}
			rowPtr = &(row.above);
		}
	}

	void removeChunk(int xIndex, int yIndex) {
		chunks.remove(Vec2i(xIndex, yIndex));
		ChunkRow** rowPtr = &lowestRow;
		while (*rowPtr !is null) {
			if ((*rowPtr).leftmost.y == yIndex) {
				Chunk* ch = (*rowPtr).leftmost;
				while (ch !is null) {
					if (ch.x == xIndex) {
						if (ch.left is null && ch.right is null) {
							*rowPtr = (*rowPtr).above;
							return;
						}
						if (ch.left !is null)
							ch.left.right = ch.right;
						if (ch.right !is null)
							ch.right.left = ch.left;
					}
					ch = ch.right;
				}
			}
			rowPtr = &((*rowPtr).above);
		}
	}

	Chunk* getChunk(int xIndex, int yIndex) {
		if (Vec2i(xIndex, yIndex) in chunks)
			return chunks[Vec2i(xIndex, yIndex)];
		else
			return null;
	}

	int absCoordToChunkIndex(int coord) {
		return coord / chunkSize - (coord < 0 ? 1 : 0);
	}

	Chunk** getChunkContaining(int x, int y) {
		return Vec2i(
			x / chunkSize - (x < 0 ? 1 : 0),
			y / chunkSize - (y < 0 ? 1 : 0)
		) in chunks;
	}

	Pixel* getPixel(int x, int y) {
		auto chunk = getChunkContaining(x, y);
		if (chunk is null)
			return null;
		return (*chunk).getPixel(x, y);
	}
}
 
void changeMaterial(Pixel* pixel, Material* newMaterial){
	pixel.material = newMaterial;
	pixel.resetColor();
}

void changeMaterial(Pixel* pixel1, Pixel* pixel2, Material* newMaterial1, Material* newMaterial2){
	pixel1.material = newMaterial1;
	pixel1.resetColor();
	pixel2.material = newMaterial2;
	pixel2.resetColor();
}