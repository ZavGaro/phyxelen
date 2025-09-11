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
	if (to.material == from.material && to.updateCounter != step) {
		int beyondX = toX * 2 - fromX;
		int beyondY = toY * 2 - fromY;
		Pixel* pixelBeyond = chunk.getPixel(beyondX, beyondY);
		if (pixelBeyond is null || pixelBeyond.updateCounter == step)
			return false;
		// writefln("%s moves %s", fromX, toX);
		if (!tryMovePixelRecursive(chunk, to, toX, toY,
			pixelBeyond, beyondX, beyondY, step))
		return false;
	}
	if (to.material.type == MaterialType.air) {
		auto air = to.material;
		*to = *from;
		*from = Pixel(air, 0, step, false, 0);
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

		// if (true){//pixels[i].updateCounter != step) {
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
				Pixel* under = getPixel(px, py - 1);
				if (/*uniform(0, 100) != 0 && */tryMovePixel(pixel, under, step))
					break;
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
					enum maxOffset = 20;
					enum fallBoostMultiplier = 1.5;
					if (uniform(0, 2) == 0) {
						if (tryMovePixel(pixel, underLeft, step)) {
							Pixel* lowerLeft = getPixel(px - 1, py - 2);
							if (lowerLeft !is null) {
								// int offset = uniform(1, maxOffset);
								float offset = uniform01() * world.targetPhyxelTps;
								throwPixel(world, underLeft, px - 1, py, -offset, -world.targetPhyxelTps * fallBoostMultiplier);
								// tryMovePixel(underLeft, getPixel(px - offset, py - offset + 1), step);
							}
							break;
						}
						if (tryMovePixel(pixel, underRight, step)) {
							Pixel* lowerRight = getPixel(px + 1, py - 2);
							if (lowerRight !is null) {
								// int offset = uniform(1, maxOffset);
								float offset = uniform01() * world.targetPhyxelTps;
								throwPixel(world, underRight, px + 1, py, offset, -world.targetPhyxelTps * fallBoostMultiplier);
								// tryMovePixel(underRight, getPixel(px + offset, py - offset + 1), step);
							}
							break;
						}
					} else {
						if (tryMovePixel(pixel, underRight, step)) {
							Pixel* lowerRight = getPixel(px + 1, py - 2);
							if (lowerRight !is null) {
								// int offset = uniform(1, maxOffset);
								float offset = uniform01() * world.targetPhyxelTps;
								throwPixel(world, underRight, px + 1, py, offset, -world.targetPhyxelTps * fallBoostMultiplier);
								// tryMovePixel(underRight, getPixel(px + offset, py - offset + 1), step);
							}
							break;
						}
						if (tryMovePixel(pixel, underLeft, step)) {
							Pixel* lowerLeft = getPixel(px - 1, py - 2);
							if (lowerLeft !is null) {
								// int offset = uniform(1, maxOffset);
								float offset = uniform01() * world.targetPhyxelTps;
								throwPixel(world, underLeft, px - 1, py, -offset, -world.targetPhyxelTps * fallBoostMultiplier);
								// tryMovePixel(underLeft, getPixel(px - offset, py - offset + 1), step);
							}
							break;
						}
					}
					
				}
				Pixel* leftPx = getPixel(px - 1, py);
				Pixel* rightPx = getPixel(px + 1, py);
				// if (uniform(0, 2) == 0) {
				// 	if (tryMovePixel(pixel, leftPx, step))
				// 		break;
				// 	if (tryMovePixel(pixel, rightPx, step))
				// 		break;
				// } else {
				// 	if (tryMovePixel(pixel, rightPx, step))
				// 		break;
				// 	if (tryMovePixel(pixel, leftPx, step))
				// 		break;
				// }
				if (uniform(0, 2) == 0) {
					tryMovePixelRecursive(&this, pixel, px, py, leftPx, px - 1, py, step, true);
				} else {
					tryMovePixelRecursive(&this, pixel, px, py, rightPx, px + 1, py, step, true);
				}
				// if (uniform(0, 2) == 0) {
				// 	if (tryMovePixelRecursive(&this, pixel, px, py, leftPx, px - 1, py, step))
				// 		break;
				// 	if (tryMovePixelRecursive(&this, pixel, px, py, rightPx, px + 1, py, step))
				// 		break;
				// } else {
				// 	if (tryMovePixelRecursive(&this, pixel, px, py, rightPx, px + 1, py, step))
				// 		break;
				// 	if (tryMovePixelRecursive(&this, pixel, px, py, leftPx, px - 1, py, step))
				// 		break;
				// }
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


struct World {
	Material[] materials;
	Chunk*[Vec2i] chunks;
	Chunk*[] leftChunks;
	ubyte stepCounter;
	float targetPhyxelTps = 20;
    float phyxelDt = 0;

	float gravity = 2;
	PixelWithVelocity[] pixelsWithVelocity;

	void step(float dt) {
		phyxelDt += dt;
		if (phyxelDt >= 1 / targetPhyxelTps) {
			bool reverse = stepCounter % 2 == 0;
			// bool reverse = false;
			foreach (first; leftChunks) {
				Chunk*[] line;
				Chunk* chunk = first;
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
				// if (reverse) {
				// 	while (chunk.right !is null)
				// 		chunk = chunk.right;
				// 	while (chunk !is null) {
				// 		// writefln("%s %s", chunk.x, chunk.y);
				// 		chunk.step(stepCounter);
				// 		chunk = chunk.left;
				// 	}
				// } else {
				// 	while (chunk !is null) {
				// 		// writefln("%s %s", chunk.x, chunk.y);
				// 		chunk.step(stepCounter);
				// 		chunk = chunk.right;
				// 	}
				// }
			}
			foreach (i, ref pixel; pixelsWithVelocity) {
				pixel.velY -= gravity;
				float newX = pixel.x + pixel.velX * dt;
				float newY = pixel.y + pixel.velY * dt;
				auto targetPx = getPixel(cast(int) round(newX), cast(int) round(newY));
				if (targetPx is null || targetPx.material.type != MaterialType.air) {
					targetPx = getPixel(cast(int) round(pixel.x), cast(int) round(pixel.y));
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

		if (leftChunks.length == 0) {
			leftChunks ~= newChunk;
			return;
		}

		foreach (i, chunk; leftChunks) {
			if (newChunk.y == chunk.y) {
				if (chunk.x > newChunk.x) {
					leftChunks[i] = newChunk;
					newChunk.right = chunk;
					chunk.left = newChunk;
				} else {
					// Inserting in bi-linked list
					Chunk* ch = chunk;
					while ( ch.right !is null && ch.right.x < newChunk.x ) {
						ch = ch.right;
					}
					if (ch.right !is null)
						ch.right.left = newChunk;
					ch.right = newChunk;
					newChunk.left = ch;
					return;
				}

			} else if (newChunk.y < chunk.y) {
				leftChunks.length += 1;
				foreach_reverse (j; i + 2 .. leftChunks.length)
					leftChunks[j - 1] = leftChunks[j - 2];
				leftChunks[i] = newChunk;
				return;
			} else if (i + 1 == leftChunks.length) {
				leftChunks ~= newChunk;
				return;
			}
		}
	}

	Chunk* getChunk(int xIndex, int yIndex) {
		if (Vec2i(xIndex, yIndex) in chunks)
			return chunks[Vec2i(xIndex, yIndex)];
		else
			return null;
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