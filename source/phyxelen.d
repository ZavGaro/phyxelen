import std.random;
debug {import std.stdio;}

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

struct Material {
	ushort id;
	MaterialType type;
	float density;
	int[] colors;
}

// struct Pixel {
// 	Chunk* chunk;
// 	ushort i;

// 	ushort materialIndex() { return chunk.materials[i]; }
// 	Material* material() { return &chunk.world.materials[chunk.materials[i]]; }
// }

struct Pixel {
	// Chunk* chunk;
	Material* material;
	// ushort material;
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
}

void swapPixels(Pixel* p1, Pixel* p2) {
	Pixel buf = *p1;
	*p1 = *p2;
	*p2 = buf;
}

bool tryMovePixel(Pixel* from, Pixel* to, ubyte step) {
	if (to is null)
		return false;
	if (to.material.type == MaterialType.air) {
		auto air = to.material;
		*to = *from;
		*from = Pixel(air, 0, 0, false, 0);
		to.updateCounter = step;
		return true;
	}
	if (to.material.density < from.material.density) {
		swapPixels(to, from);
		to.updateCounter = step;
		return true;
	}
	return false;
}

enum chunkSize = 64;
enum chunkArea = chunkSize * chunkSize;

struct Chunk {
	World* world;
	int x, y;
	Chunk* left, right; /// Nearest chunks on sides. Can be not neighbors
	// ushort[chunkArea] materials;
	// ubyte[chunkArea] colors;
	// int[] colorOverrides;
	Pixel[chunkArea] pixels;

	void step(ubyte step) {
		bool reverse = step % 2 == 1;
		// bool reverse = false;
		auto rand = Random(step + x + y * 3);
		with (MaterialType) {
		int i = reverse ? chunkSize - 1 : 0;
		// writeln();
		for (;;) {
			if (pixels[i].updateCounter != step) {
				// write(' ', i);
			// if (true){//pixels[i].updateCounter != step) {
				int px = this.x * chunkSize + i % chunkSize;
				int py = this.y * chunkSize + i / chunkSize;
				// final switch (world.materials[pixels[i].material].type) {
				auto thisMat = pixels[i].material;
				final switch (thisMat.type) {
				case air, solid: break;
				case powder: {
					Pixel* under = getPixel(px, py - 1);
					if (tryMovePixel(&pixels[i], under, step))
						break;
					// if (under !is null && under.updateCounter != step) {
					// 	if (under.material.type == MaterialType.air) {
					// 		pixels[i].updateCounter = step;
					// 		*under = pixels[i];
					// 		// pixels[i] = Pixel(&world.materials[0], 0, false, 0);
					// 		pixels[i].material = &world.materials[0];
					// 		break;
					// 	} else if (under.material.density < thisMat.density) {
					// 		pixels[i].updateCounter = step;
					// 		swapPixels(under, &pixels[i]);
					// 		break;
					// 	}
					// }
					Pixel* underLeft = getPixel(px - 1, py - 1);
					Pixel* underRight = getPixel(px + 1, py - 1);
					if (uniform(0, 2) == 0) {
						if (tryMovePixel(&pixels[i], underLeft, step))
							break;
						if (tryMovePixel(&pixels[i], underRight, step))
							break;
					} else {
						if (tryMovePixel(&pixels[i], underRight, step))
							break;
						if (tryMovePixel(&pixels[i], underLeft, step))
							break;
					}
					// bool canGoUnderLeft = underLeft !is null && underLeft.updateCounter != step
					// 	&& (underLeft.material.type == MaterialType.air
					// 		|| underLeft.material.density < thisMat.density);
					// bool canGoUnderRight = underRight !is null && underRight.updateCounter != step
					// 	&& (underRight.material.type == MaterialType.air
					// 		|| underRight.material.density < thisMat.density);
					// if (canGoUnderLeft) {
					// 	if (canGoUnderRight && uniform(0, 2) == 0) {
					// 		pixels[i].updateCounter = step;
					// 		swapPixels(underRight, &pixels[i]);
					// 		break;
					// 	}
					// 	pixels[i].updateCounter = step;
					// 	swapPixels(underLeft, &pixels[i]);
					// 	break;
					// }
					// if (canGoUnderRight) {
					// 	pixels[i].updateCounter = step;
					// 	swapPixels(underRight, &pixels[i]);
					// }
					break;
				}
				case liquid: {
					Pixel* under = getPixel(px, py - 1);
					if (/*uniform(0, 100) != 0 && */tryMovePixel(&pixels[i], under, step))
						break;
					Pixel* underLeft = getPixel(px - 1, py - 1);
					Pixel* underRight = getPixel(px + 1, py - 1);
					version (noSplat) {
						if (uniform(0, 2) == 0) {
							if (tryMovePixel(&pixels[i], underLeft, step))
								break;
							if (tryMovePixel(&pixels[i], underRight, step))
								break;
						} else {
							if (tryMovePixel(&pixels[i], underRight, step))
								break;
							if (tryMovePixel(&pixels[i], underLeft, step))
								break;
						}
					} else {
						enum maxOffset = 3;
						if (uniform(0, 2) == 0) {
							if (tryMovePixel(&pixels[i], underLeft, step)) {
								Pixel* lowerLeft = getPixel(px - 1, py - 2);
								if (lowerLeft !is null) {// && lowerLeft.material.type == MaterialType.air) {
									int offset = uniform(1, maxOffset);
									tryMovePixel(underLeft, getPixel(px - offset, py - offset + 1), step);
								}
								break;
							}
							if (tryMovePixel(&pixels[i], underRight, step)) {
								Pixel* lowerRight = getPixel(px + 1, py - 2);
								if (lowerRight !is null) {// && lowerRight.material.type == MaterialType.air) {
									int offset = uniform(1, maxOffset);
									tryMovePixel(underRight, getPixel(px + offset, py - offset + 1), step);
								}
								break;
							}
						} else {
							if (tryMovePixel(&pixels[i], underRight, step)) {
								Pixel* lowerRight = getPixel(px + 1, py - 2);
								if (lowerRight !is null) {// && lowerRight.material.type == MaterialType.air) {
									int offset = uniform(1, maxOffset);
									tryMovePixel(underRight, getPixel(px + offset, py - offset + 1), step);
								}
								break;
							}
							if (tryMovePixel(&pixels[i], underLeft, step)) {
								Pixel* lowerLeft = getPixel(px - 1, py - 2);
								if (lowerLeft !is null) {// && lowerLeft.material.type == MaterialType.air) {
									int offset = uniform(1, maxOffset);
									tryMovePixel(underLeft, getPixel(px - offset, py - offset + 1), step);
								}
								break;
							}
						}
						
					}
					Pixel* leftPx = getPixel(px - 1, py);
					Pixel* rightPx = getPixel(px + 1, py);
					// if (uniform(0, 2) == 0) {
					// 	if (tryMovePixel(&pixels[i], leftPx, step)) {
					// 		if (underLeft !is null && underLeft.material.type == MaterialType.air)
					// 			tryMovePixel(&pixels[i], getPixel(px - uniform(1, 4), py), step);
					// 		break;
					// 	}
					// 	if (tryMovePixel(&pixels[i], rightPx, step)) {
					// 		if (underRight !is null && underRight.material.type == MaterialType.air)
					// 			tryMovePixel(&pixels[i], getPixel(px + uniform(1, 4), py), step);
					// 		break;
					// 	}
					// } else {
					// 	if (tryMovePixel(&pixels[i], rightPx, step)) {
					// 		if (underRight !is null && underRight.material.type == MaterialType.air)
					// 			tryMovePixel(&pixels[i], getPixel(px + uniform(1, 4), py), step);
					// 		break;
					// 	}
					// 	if (tryMovePixel(&pixels[i], leftPx, step)) {
					// 		if (underLeft !is null && underLeft.material.type == MaterialType.air)
					// 			tryMovePixel(&pixels[i], getPixel(px - uniform(1, 4), py), step);
					// 		break;
					// 	}
					// }
					if (uniform(0, 2) == 0) {
						if (tryMovePixel(&pixels[i], leftPx, step))
							break;
						if (tryMovePixel(&pixels[i], rightPx, step))
							break;
					} else {
						if (tryMovePixel(&pixels[i], rightPx, step))
							break;
						if (tryMovePixel(&pixels[i], leftPx, step))
							break;
					}

					// Pixel* under = getPixel(px, py - 1);
					// if (under !is null && under.updateCounter != step) {
					// 	if (under.material.type == MaterialType.air) {
					// 		pixels[i].updateCounter = step;
					// 		*under = pixels[i];
					// 		pixels[i].material = &world.materials[0];
					// 		break;
					// 	} else if (under.material.density < thisMat.density) {
					// 		pixels[i].updateCounter = step;
					// 		swapPixels(under, &pixels[i]);
					// 		break;
					// 	}
					// }
					// Pixel* underLeft = getPixel(px - 1, py - 1);
					// Pixel* underRight = getPixel(px + 1, py - 1);
					// bool canGoUnderLeft = underLeft !is null && underLeft.updateCounter != step
					// 	&& (underLeft.material.type == MaterialType.air
					// 		|| underLeft.material.density < thisMat.density);
					// bool canGoUnderRight = underRight !is null && underRight.updateCounter != step
					// 	&& (underRight.material.type == MaterialType.air
					// 		|| underRight.material.density < thisMat.density);
					// if (canGoUnderLeft) {
					// 	if (canGoUnderRight && uniform(0, 2) == 0) {
					// 		pixels[i].updateCounter = step;
					// 		swapPixels(underRight, &pixels[i]);
					// 		break;
					// 	}
					// 	pixels[i].updateCounter = step;
					// 	swapPixels(underLeft, &pixels[i]);
					// 	break;
					// }
					// if (canGoUnderRight) {
					// 	pixels[i].updateCounter = step;
					// 	swapPixels(underRight, &pixels[i]);
					// 	break;
					// }
					// Pixel* leftPx = getPixel(px - 1, py);
					// Pixel* rightPx = getPixel(px + 1, py);
					// if (leftPx !is null && leftPx.updateCounter != step) {
					// 	if (leftPx.material.type == MaterialType.air) {
					// 		if (rightPx !is null && rightPx.updateCounter != step) {
					// 			if (rightPx.material.type == MaterialType.air) {
					// 				pixels[i].updateCounter = step;
					// 				*rightPx = pixels[i];
					// 				pixels[i].material = &world.materials[0];
					// 				break;
					// 			} else if (rightPx.material.density < thisMat.density) {
					// 				pixels[i].updateCounter = step;
					// 				swapPixels(rightPx, &pixels[i]);
					// 				break;
					// 			}
					// 		}
					// 		*leftPx = pixels[i];
					// 		pixels[i].material = &world.materials[0];
					// 		break;
					// 	} else if (leftPx.material.density < thisMat.density) {
					// 		if (rightPx !is null && rightPx.updateCounter != step) {
					// 			if (rightPx.material.type == MaterialType.air) {
					// 				pixels[i].updateCounter = step;
					// 				*rightPx = pixels[i];
					// 				pixels[i].material = &world.materials[0];
					// 				break;
					// 			} else if (rightPx.material.density < thisMat.density) {
					// 				pixels[i].updateCounter = step;
					// 				swapPixels(rightPx, &pixels[i]);
					// 				break;
					// 			}
					// 		}
					// 		swapPixels(leftPx, &pixels[i]);
					// 		break;
					// 	}
					// }
					// if (rightPx !is null && rightPx.updateCounter != step) {
					// 	if (rightPx.material.type == MaterialType.air) {
					// 		*rightPx = pixels[i];
					// 		pixels[i].material = &world.materials[0];
					// 		break;
					// 	} else if (rightPx.material.density < thisMat.density) {
					// 		swapPixels(rightPx, &pixels[i]);
					// 		break;
					// 	}
					// }
					break;
				}
				case gas: {
					Pixel* above = getPixel(px, py + 1);
					if (tryMovePixel(&pixels[i], above, step))
						break;
					Pixel* aboveLeft = getPixel(px - 1, py + 1);
					Pixel* aboveRight = getPixel(px + 1, py + 1);
					if (uniform(0, 2) == 0) {
						if (tryMovePixel(&pixels[i], aboveLeft, step))
							break;
						if (tryMovePixel(&pixels[i], aboveRight, step))
							break;
					} else {
						if (tryMovePixel(&pixels[i], aboveRight, step))
							break;
						if (tryMovePixel(&pixels[i], aboveLeft, step))
							break;
					}
					Pixel* leftPx = getPixel(px - 1, py);
					Pixel* rightPx = getPixel(px + 1, py);
					if (uniform(0, 2) == 0) {
						if (tryMovePixel(&pixels[i], leftPx, step))
							break;
						if (tryMovePixel(&pixels[i], rightPx, step))
							break;
					} else {
						if (tryMovePixel(&pixels[i], rightPx, step))
							break;
						if (tryMovePixel(&pixels[i], leftPx, step))
							break;
					}
					break;
				}
				} 
			}
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
	}

	Pixel* getPixel(int x, int y) {
		int cx = this.x * chunkSize;
		int cy = this.y * chunkSize;
		// writeln(Vec2i(cx, cy));
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
			// writeln(Vec2i(cx, cy));
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
			// return Pixel(&this, cast(ushort) (x - cx + (y - cy) * chunkSize));
			return &pixels[x - cx + (y - cy) * chunkSize];
		}
	}
}

// struct BiLinkedListNode(T) {
// 	T* content;
// 	BiLinkedListNode!T* next;
// 	BiLinkedListNode!T* prev;
// }
// struct BiLinkedList(T) {
// 	BiLinkedListNode!T* node;
// 	BiLinkedListNode!T* head;
// 	BiLinkedListNode!T* end;
// }

struct World {
	// BiLinkedList!(BiLinkedList!Chunk) chunks;
	Material[] materials;
	Chunk*[Vec2i] chunks;
	Chunk*[] leftChunks;
	ubyte stepCounter;
	float targetPhyxelTps = 20;
    float phyxelDt = 0;

	void step(float dt) {
		phyxelDt += dt;
		if (phyxelDt >= 1 / targetPhyxelTps) {
			foreach (first; leftChunks) {
				auto chunk = first;
				while (chunk !is null) {
					// writefln("%s %s", chunk.x, chunk.y);
					chunk.step(stepCounter);
					chunk = chunk.right;
				}
			}
			// foreach (chunk; chunks) {
			// 	chunk.step(stepCounter);
			// }
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
		// foreach (chunk; leftChunks) {
		// 	if (yIndex == chunk.y) {
		// 		Chunk* ch = chunk;
		// 		while (ch !is null) {
		// 			if (xIndex == ch.x)
		// 				return ch;
		// 			else if (xIndex > ch.x)
		// 				return null;
		// 		}
		// 		return null;
		// 	} else if (yIndex > chunk.y)
		// 		return null;
		// }
		// return null;
		return chunks[Vec2i(xIndex, yIndex)];
	}
}

// 