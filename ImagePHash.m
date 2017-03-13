//
//  ImagePHash.m
//  CompareImage
//
//  Created by 张齐朴 on 15/12/3.
//  Copyright © 2015年 张齐朴. All rights reserved.
//
// 参照博客 http://www.cnblogs.com/lixun/p/4334977.html
// 第一步，缩小尺寸
//
// 将图片缩小到8x8的尺寸，总共64个像素。这一步的作用是去除图片的细节，只保留结构、明暗等基本信息，摒弃不同尺寸、比例带来的图片差异。
//
// 用汉明距离进行图片相似度检测的Java实现 用汉明距离进行图片相似度检测的Java实现
//
// 第二步，简化色彩。
//
// 将缩小后的图片，转为64级灰度。也就是说，所有像素点总共只有64种颜色。
//
// 第三步，计算平均值。
//
// 计算所有64个像素的灰度平均值。
//
// 第四步，比较像素的灰度。
//
// 将每个像素的灰度，与平均值进行比较。大于或等于平均值，记为1；小于平均值，记为0。
//
// 第五步，计算哈希值。
//

#import "ImagePHash.h"

@interface ImagePHash ()
{
    int    _size;
    int    _smallerSize;
    NSMutableArray *_c;
}
@end

@implementation ImagePHash

- (instancetype)init
{
    if (self = [super init]) {
        
        _smallerSize = 8;
        _size = 32;
        [self initCoefficients];
    }
    
    return self;
}

// Resize the image size to 8 * 8
- (UIImage *)resizedImage:(UIImage *)image withSize:(CGSize)size
{
    UIImage *resizedImage = nil;
    
    UIGraphicsBeginImageContext(size);
    
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    resizedImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return resizedImage;
}

// Get the grayed color image
- (UIImage *)grayedImage:(UIImage *)image
{
    UIImage *grayedImage = nil;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    CGContextRef    ctx        = CGBitmapContextCreate(nil,
                                                       image.size.width,
                                                       image.size.height,
                                                       8,
                                                       0,
                                                       colorSpace,
                                                       kCGImageAlphaNone);
    CGColorSpaceRelease(colorSpace);
    
    if (ctx == NULL) return nil;
    
    CGContextDrawImage(ctx, CGRectMake(0, 0, image.size.width, image.size.height), image.CGImage);
    grayedImage = [UIImage imageWithCGImage:CGBitmapContextCreateImage(ctx)];
    CGContextRelease(ctx);
    
    return grayedImage;
}

- (void)initCoefficients
{
    _c = [NSMutableArray arrayWithCapacity:_size];
    [_c addObject:@(1 / sqrt(2.0))];
    
    for (int i = 1; i < _size; i++) {
        [_c addObject:@1.0];
    }
}

// eg: arr[size][size] = {{0.0, 0.0, ...}, {0.0, 0.0, ...}, ...}
- (NSMutableArray *)allocateTwoDimension
{
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:_size];
    for (int i = 0; i < _size; i++) {
        NSMutableArray *item = [NSMutableArray arrayWithCapacity:_size];
        for (int j = 0; j < _size; j++) {
            [item addObject:@0.0];
        }
        
        [arr addObject:item];
    }
    
    return arr;
}

// Get RGB color the blue value
- (CGFloat)getBlueWithImage:(UIImage *)image atPoint:(CGPoint)point
{
    // Cancel if point is outside image coordinates
    NSInteger pointX = trunc(point.x);
    NSInteger pointY = trunc(point.y);
    
    CGImageRef cgImage = image.CGImage;
    NSUInteger width = image.size.width;
    NSUInteger height = image.size.height;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    int bytesPerPixel = 4;
    int bytesPerRow = bytesPerPixel * 1;
    NSUInteger bitsPerComponent = 8;
    unsigned char pixelData[4] = { 0, 0, 0, 0 };
    
    CGContextRef context = CGBitmapContextCreate(pixelData,
                                                 1,
                                                 1,
                                                 bitsPerComponent,
                                                 bytesPerRow,
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    
    CGColorSpaceRelease(colorSpace);
    CGContextSetBlendMode(context, kCGBlendModeCopy);
    // Draw the pixel we are interested in onto the bitmap context
    
    CGContextTranslateCTM(context, -pointX, pointY-(CGFloat)height);
    CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, (CGFloat)width, (CGFloat)height), cgImage);
    CGContextRelease(context);
    
    // Convert color values [0..255] to floats [0.0..1.0]
    
    CGFloat blue  = (CGFloat)pixelData[2] / 255.0f;
    return blue;
}

- (NSArray *)applyDCT:(NSArray *)f
{
    int N = _size;
    NSMutableArray *F = [self allocateTwoDimension];

    for (int u = 0; u < N; u++) {
        for (int v = 0; v < N; v++) {
            double sum = 0.0;
            for (int i = 0; i < N; i++) {
                for (int j = 0; j < N; j++) {
                    sum += cos(((2 * i + 1) / (2.0 * N)) * u * M_PI) * cos(((2 * j + 1) / (2.0 * N)) * v * M_PI) * ([f[i][j] doubleValue]);
                }
            }
            
            sum *= (([_c[u] doubleValue] * [_c[v] doubleValue]) / 4.0);
            F[u][v] = @(sum);
        }
    }
    
    return F;
}

- (NSString *)getHashWithImage:(UIImage *)image
{
    // Set the image size (8, 8)
    UIImage *img = [self resizedImage:image withSize:CGSizeMake(8, 8)];
    // Set the image grayed space color
    img          = [self grayedImage:img];
    

    float valsF[8][8];
    for (int x = 0; x < img.size.width; x++) {
        for (int y = 0; y < img.size.height; y++) {
            valsF[x][y] =[self getBlueWithImage:img atPoint:CGPointMake(x, y)];
        }
    }
    
    int N = 8;
    float F[8][8];
    
    for (int u = 0; u < N; u++) {
        for (int v = 0; v < N; v++) {
            double sum = 0.0;
            for (int i = 0; i < N; i++) {
                for (int j = 0; j < N; j++) {
                    sum += cos(((2 * i + 1) / (2.0 * N)) * u * M_PI) * cos(((2 * j + 1) / (2.0 * N)) * v * M_PI) * ((double)valsF[i][j]);
                }
            }
            sum *= (([_c[u] doubleValue] * [_c[v] doubleValue]) / 4.0);
            F[u][v] = sum;
        }
    }
    
    double total = 0;
    
    for (int x = 0; x < _smallerSize; x++) {
        for (int y = 0; y < _smallerSize; y++) {
            total += (double)F[x][y];
        }
    }
    
    total -= (double)F[0][0];
    double avg = total / (double) ((_smallerSize * _smallerSize) - 1);

    NSMutableString *hash = [NSMutableString stringWithString:@""];
    
    for (int x = 0; x < _smallerSize; x++) {
        for (int y = 0; y < _smallerSize; y++) {
            if (x != 0 && y != 0) {
                [hash appendString:(double)F[x][y] > avg ? @"1":@"0"];
            }
        }
    }
    
    return hash;
}

// The hanming distance, the two images are different when the hanming distance > 10
// two images are the same when hanming distance close to 0.
+ (int)distance:(NSString *)PHashStr1 betweenS2:(NSString *)PHashStr2
{
    int counter = 0;
    for (int k = 0; k < PHashStr1.length; k++) {
        if([PHashStr1 characterAtIndex:k] != [PHashStr2 characterAtIndex:k]) {
            counter++;
        }
    }
    
    return counter;
}

@end
