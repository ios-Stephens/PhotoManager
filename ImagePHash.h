//
//  ImagePHash.h
//  CompareImage
//
//  Created by 张齐朴 on 15/12/3.
//  Copyright © 2015年 张齐朴. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ImagePHash : NSObject

- (NSString *)getHashWithImage:(UIImage *)image;

+ (int)distance:(NSString *)PHashStr1 betweenS2:(NSString *)PHashStr2;

@end
