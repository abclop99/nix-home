#include <stdint.h>

#include "filter.h"

void swaylock_effect(uint32_t *data, int width, int height, int scale)
{
	for (int x = 0; x < width; x++) {
		for (int y = 0; y < height; y++) {
			unsigned char *pix = (unsigned char *)(data + y * width + x);

			// 2300k color temp from
			// http://vendian.org/mncharity/dir3/blackbody/unstableURLs/bbr_color.html
			// 255 157 51
			pix[0] = (unsigned char) (pix[0] * (51  / 255.0));  // B
			pix[1] = (unsigned char) (pix[1] * (157 / 255.0));  // G
			pix[2] = (unsigned char) (pix[2] * (255 / 255.0));  // R

			// Dim the image slightly
			pix[0] = (unsigned char) (pix[0] * 0.9);  // B
			pix[1] = (unsigned char) (pix[1] * 0.9);  // G
			pix[2] = (unsigned char) (pix[2] * 0.9);  // R
		}
	}
}
