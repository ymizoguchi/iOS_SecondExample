//
//  ViewController.m
//  SecondExample
//
//  Created by Yoshihiro Mizoguchi on 2013/08/16.
//  Copyright (c) 2013年 Yoshihiro Mizoguchi. All rights reserved.
//

#import "ViewController.h"

// 描画用サンプルデータ
#define RED   1.0f, 0.0f, 0.0f, 1.0f
#define GREEN 0.0f, 1.0f, 0.0f, 1.0f
#define BLUE  0.0f, 0.0f, 1.0f, 1.0f
#define BLACK 0.0f, 0.0f, 0.0f, 1.0f
#define WHITE 1.0f, 1.0f, 1.0f, 1.0f

#define LEFT_TOP 0.0f, 0.0f
#define LEFT_BOTTOM 0.0f, 1.0f
#define RIGHT_TOP 1.0f, 0.0f
#define RIGHT_BOTTOM 1.0f, 1.0f

// 四角形 (GL_TRIANGLE_STRIPで表示)
GLfloat square_points[] = {
    0.0f, 0.0f,
    1.0f, 0.0f,
    0.0f, 1.0f,
    1.0f, 1.0f
};

GLfloat texcoords[] = {
    LEFT_BOTTOM,
    RIGHT_BOTTOM,
    LEFT_TOP,
    RIGHT_TOP
};


@interface ViewController () {
    // Shaderへ渡す変換行列
    GLKMatrix4 _modelViewProjectionMatrix;
    // Shaderを定義するプログラム変数
    GLuint _program;
    // アニメーション用変数 回転(_rotation), 速度(_speed), 仰角(_angle)
    float _rotation;
    float _speed;
    float _angle;
    // Shaderとの変数連結用
    GLuint _position;
    GLuint _texcoord;
    GLuint _textureImageUniform;
    GLuint _modelViewUniform;
    // テクスチャ
    GLuint _texname;
}
// Open GL描画管理オブジェクト
@property (strong, nonatomic) EAGLContext *context;
@end

@implementation ViewController

// 最初に1回実行される
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // 最初は回転速度と仰角
    _speed = 2.0f;
    _angle = 0.1f;
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    [EAGLContext setCurrentContext:self.context];
    
    // マウス入力があるとhandleTapFromを呼ぶようにする
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapFrom:)];
    [self.view addGestureRecognizer:tapRecognizer];
    
    // vertex shader (VertexShader.vsh を参照するようにする)
    NSString *vertexShaderSource = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"VertexShader" ofType:@"vsh"] encoding:NSUTF8StringEncoding error:nil];
    const char *vertexShaderSourceCString = [vertexShaderSource cStringUsingEncoding:NSUTF8StringEncoding];
    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vertexShaderSourceCString, NULL);
    glCompileShader(vertexShader);
    // fragment shader (FragmentShader.fsh を参照するようにする)
    NSString *fragmentShaderSource = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"FragmentShader" ofType:@"fsh"] encoding:NSUTF8StringEncoding error:nil];
    const char *fragmentShaderSourceCString = [fragmentShaderSource cStringUsingEncoding:NSUTF8StringEncoding];
    GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragmentShaderSourceCString, NULL);
    glCompileShader(fragmentShader);
    // Create and link program
    _program = glCreateProgram();
    glAttachShader(_program, vertexShader);
    glAttachShader(_program, fragmentShader);
    glLinkProgram(_program);
    
    // shaderとの変数や配列の連結
    _position = glGetAttribLocation(_program, "position");
    _texcoord = glGetAttribLocation(_program, "texcoord");
    glEnableVertexAttribArray(_position);
    glEnableVertexAttribArray(_texcoord);
    _textureImageUniform = glGetUniformLocation(_program, "textureImage");
    _modelViewUniform = glGetUniformLocation(_program, "modelViewProjectionMatrix");
    
    // texture画像の読み込み (_texname)
    CGImageRef spriteImage = [UIImage imageNamed:@"ym.png"].CGImage;
    size_t width = CGImageGetWidth(spriteImage);
    size_t height = CGImageGetHeight(spriteImage);
    GLubyte * spriteData = (GLubyte *) calloc(width*height*4, sizeof(GLubyte));
    CGContextRef spriteContext = CGBitmapContextCreate(spriteData, width, height, 8, width*4, CGImageGetColorSpace(spriteImage), kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(spriteContext, CGRectMake(0, 0, width, height), spriteImage);
    CGContextRelease(spriteContext);
    glGenTextures(1, &_texname);
    glBindTexture(GL_TEXTURE_2D, _texname);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, spriteData);
    free(spriteData);
}

// マウス入力時に呼ばれる関数 (クリック位置の上下で仰角を増減)
- (void)handleTapFrom:(UITapGestureRecognizer *)recognizer {
    CGPoint touchLocation = [recognizer locationInView:recognizer.view];
    touchLocation = CGPointMake(touchLocation.x, 320 - touchLocation.y);
    if (touchLocation.y < 160) {
        _angle -= 0.1f;
    } else {
        _angle += 0.1f;
    }
}

- (void)update
{
    // 何も書かないがメソッドは準備しておく (viewが呼ばれる)
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    // 変換行列の準備
    float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
    
    GLKMatrix4 baseModelViewMatrix2 = GLKMatrix4MakeTranslation(0.0f, 0.0f, 0.0f);
    baseModelViewMatrix2 = GLKMatrix4Rotate(baseModelViewMatrix2, _rotation, 0.0f, 1.0f, 0.0f);
    // 回転角の更新
    _rotation += self.timeSinceLastUpdate * _speed;
    
    // 視点はz軸方向に下がって, 少し上から回転しないことにする.
    GLKMatrix4 modelViewMatrix = GLKMatrix4MakeTranslation(0.0f, -0.5f, -4.0f);
    modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, _angle, 1.0f, 0.0f, 0.0f);
    GLKMatrix4 modelViewMatrix2 = GLKMatrix4Multiply(modelViewMatrix,baseModelViewMatrix2);
    
    // 背景は白にする.
    glClearColor(WHITE);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // Shaderプログラムを指定する.
    glUseProgram(_program);
    // Textureを指定する.
    glBindTexture(GL_TEXTURE_2D, _texname);
    glUniform1i(_textureImageUniform, 0);
    
    // 四角形 (変換行列, 点座標, 色, 表示GL_LINE_STRIP)
    _modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix2);
    glUniformMatrix4fv(_modelViewUniform, 1, 0, _modelViewProjectionMatrix.m);
    glVertexAttribPointer(_position, 2, GL_FLOAT, GL_FALSE, 0, square_points);
    glEnableVertexAttribArray(_position);
    glVertexAttribPointer(_texcoord, 2, GL_FLOAT, GL_FALSE, 0, texcoords);
    glEnableVertexAttribArray(_texcoord);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
}

@end