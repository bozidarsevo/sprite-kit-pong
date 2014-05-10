//
//  SKPMyScene.m
//  Sprite Kit Pong
//
//  Created by Božidar Ševo on 10/05/14.
//  Copyright (c) 2014 Božidar Ševo. All rights reserved.
//

#import "SKPMyScene.h"

#define kPaddleWidth 20.0 //width of the paddles
#define kPaddleHeight 80.0 //height of the paddles
#define kBallRadius 20.0 //radius of the moving ball
#define kStartingVelocityX 150.0 //starting velocity x value for moving the ball
#define kStartingVelocityY -150.0 //starting velocity y value for moving the ball
#define kVelocityMultFactor 1.05 //multiply factor for speeding up the ball after some time
#define kIpadMultFactor 2.0 //multiply factor for ipad object scaling
#define kSpeedupInterval 5.0 //interval after which the speedUpTheBall method is called
#define kScoreFontSize 30.0 //font size of score label nodes
#define kRestartGameWidthHeight 50.0 //width and height of restart node
#define kPaddleMoveMult 1.5 //multiply factor when moving fingers to move the paddles, by moving finger for N pt it will move it for N * kPaddleMoveMult

//categories for detecting contacts between nodes
static const uint32_t ballCategory  = 0x1 << 0;
static const uint32_t cornerCategory = 0x1 << 1;
static const uint32_t paddleCategory = 0x1 << 2;

@interface SKPMyScene ()

@property(nonatomic) BOOL isPlayingGame;
//ball node
@property(nonatomic) SKSpriteNode *ballNode;
//paddle nodes
@property(nonatomic) SKSpriteNode *playerOnePaddleNode;
@property(nonatomic) SKSpriteNode *playerTwoPaddleNode;
//score label nodes
@property(nonatomic) SKLabelNode *playerOneScoreNode;
@property(nonatomic) SKLabelNode *playerTwoScoreNode;
//restart game node
@property(nonatomic) SKSpriteNode *restartGameNode;
//start game info node
@property(nonatomic) SKLabelNode *startGameInfoNode;
//touches
@property(nonatomic) UITouch *playerOnePaddleControlTouch;
@property(nonatomic) UITouch *playerTwoPaddleControlTouch;
//score
@property(nonatomic) NSInteger playerOneScore;
@property(nonatomic) NSInteger playerTwoScore;
//timer for speed-up
@property(nonatomic) NSTimer *speedupTimer;

@end

@implementation SKPMyScene

-(id)initWithSize:(CGSize)size {    
    if (self = [super initWithSize:size])
    {
        /* Setup your scene here */
        
        self.backgroundColor = [SKColor blackColor];
        
        self.physicsWorld.contactDelegate = self;
        self.physicsWorld.gravity = CGVectorMake(0, 0);
        
        //setup physics body for scene
        [self setPhysicsBody:[SKPhysicsBody bodyWithEdgeLoopFromRect:self.frame]];
        self.physicsBody.categoryBitMask = cornerCategory;
        NSLog(@"category %d",self.physicsBody.categoryBitMask);
        self.physicsBody.dynamic = NO;
        self.physicsBody.friction = 0.0;
        self.physicsBody.restitution = 1.0;
        
        //dimensions etc.
        CGFloat paddleWidth = kPaddleWidth;
        CGFloat paddleHeight = kPaddleHeight;
        CGFloat middleLineWidth = 4.0;
        CGFloat middleLineHeight = 20.0;
        CGFloat scoreFontSize = kScoreFontSize;
        CGFloat restartNodeWidthHeight = kRestartGameWidthHeight;
        //scaling for ipad
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        {
            paddleWidth *= kIpadMultFactor;
            paddleHeight *= kIpadMultFactor;
            middleLineWidth *= kIpadMultFactor;
            middleLineHeight *= kIpadMultFactor;
            scoreFontSize *= kIpadMultFactor;
            restartNodeWidthHeight *= kIpadMultFactor;
        }
        
        //middle line
        NSInteger numberOfLines = size.height / (2*middleLineHeight);
        CGPoint linePosition = CGPointMake(size.width / 2.0, middleLineHeight * 1.5);
        for (NSInteger i = 0; i < numberOfLines; i++)
        {
            SKSpriteNode *lineNode = [SKSpriteNode spriteNodeWithColor:[SKColor colorWithWhite:1.0 alpha:0.5] size:CGSizeMake(middleLineWidth, middleLineHeight)];
            lineNode.position = linePosition;
            linePosition.y += 2*middleLineHeight;
            [self addChild:lineNode];
        }
        
        //paddles
        self.playerOnePaddleNode = [SKSpriteNode spriteNodeWithColor:[SKColor whiteColor] size:CGSizeMake(paddleWidth, paddleHeight)];
        self.playerTwoPaddleNode = [SKSpriteNode spriteNodeWithColor:[SKColor whiteColor] size:CGSizeMake(paddleWidth, paddleHeight)];
        self.playerOnePaddleNode.position = CGPointMake(self.playerOnePaddleNode.size.width, CGRectGetMidY(self.frame));
        self.playerTwoPaddleNode.position = CGPointMake(CGRectGetMaxX(self.frame) - self.playerTwoPaddleNode.size.width, CGRectGetMidY(self.frame));
        self.playerOnePaddleNode.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:self.playerOnePaddleNode.size];
        self.playerOnePaddleNode.physicsBody.categoryBitMask = paddleCategory;
        self.playerTwoPaddleNode.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:self.playerTwoPaddleNode.size];
        self.playerTwoPaddleNode.physicsBody.categoryBitMask = paddleCategory;
        self.playerOnePaddleNode.physicsBody.dynamic = self.playerTwoPaddleNode.physicsBody.dynamic = NO;
        [self addChild:self.playerOnePaddleNode];
        [self addChild:self.playerTwoPaddleNode];
        
        //score labels
        self.playerOneScoreNode = [SKLabelNode labelNodeWithFontNamed:@"Helvetica"];
        self.playerTwoScoreNode = [SKLabelNode labelNodeWithFontNamed:@"Helvetica"];
        self.playerOneScoreNode.fontColor = self.playerTwoScoreNode.fontColor = [SKColor whiteColor];
        self.playerOneScoreNode.fontSize = self.playerTwoScoreNode.fontSize = scoreFontSize;
        self.playerOneScoreNode.position = CGPointMake(size.width * 0.25, size.height - scoreFontSize * 2.0);
        self.playerTwoScoreNode.position = CGPointMake(size.width * 0.75, size.height - scoreFontSize * 2.0);
        [self addChild:self.playerOneScoreNode];
        [self addChild:self.playerTwoScoreNode];
        
        //restart node
        self.restartGameNode = [SKSpriteNode spriteNodeWithImageNamed:@"restartNode.png"];
        self.restartGameNode.size = CGSizeMake(restartNodeWidthHeight, restartNodeWidthHeight);
        self.restartGameNode.position = CGPointMake(size.width / 2.0, size.height - restartNodeWidthHeight);
        self.restartGameNode.hidden = YES;
        [self addChild:self.restartGameNode];
        
        //start game info node
        self.startGameInfoNode = [SKLabelNode labelNodeWithFontNamed:@"Helvetica"];
        self.startGameInfoNode.fontColor = [SKColor whiteColor];
        self.startGameInfoNode.fontSize = scoreFontSize;
        self.startGameInfoNode.position = CGPointMake(size.width / 2.0, size.height / 2.0);
        self.startGameInfoNode.text = @"Tap to start!";
        [self addChild:self.startGameInfoNode];
        
        //set scores to 0
        self.playerOneScore = 0;
        self.playerTwoScore = 0;
        [self updateScoreLabels];
    }
    return self;
}

-(void)willMoveFromView:(SKView *)view
{
    //reset timer
    [self.speedupTimer invalidate];
    self.speedupTimer = nil;
}

-(void)startPlayingTheGame
{
    self.isPlayingGame = YES;
    self.startGameInfoNode.hidden = YES;
    self.restartGameNode.hidden = NO;
    //
    CGFloat ballWidth = kBallRadius * 2.0;
    CGFloat ballHeight = kBallRadius * 2.0;
    CGFloat ballRadius = kBallRadius;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        ballWidth *= kIpadMultFactor;
        ballHeight *= kIpadMultFactor;
        ballRadius *= kIpadMultFactor;
    }
    //make the ball
    self.ballNode = [SKSpriteNode spriteNodeWithImageNamed:@"circleNode.png"];
    self.ballNode.size = CGSizeMake(ballWidth, ballHeight);
    self.ballNode.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:ballRadius];
    self.ballNode.physicsBody.categoryBitMask = ballCategory;
    self.ballNode.physicsBody.contactTestBitMask = cornerCategory | paddleCategory;
    self.ballNode.physicsBody.linearDamping = 0.0;
    self.ballNode.physicsBody.angularDamping = 0.0;
    self.ballNode.physicsBody.restitution = 1.0;
    self.ballNode.physicsBody.dynamic = YES;
    self.ballNode.physicsBody.friction = 0.0;
    self.ballNode.physicsBody.allowsRotation = NO;
    self.ballNode.position = CGPointMake(self.size.width/2.0, self.size.height/2.0);
    
    [self addChild:self.ballNode];
    
    CGFloat startingVelocityX = kStartingVelocityX;
    CGFloat startingVelocityY = kStartingVelocityY;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        startingVelocityX *= kIpadMultFactor;
        startingVelocityY *= kIpadMultFactor;
    }
    if (self.playerOneScore > self.playerTwoScore)
    {
        startingVelocityX = -startingVelocityX;
    }
    self.ballNode.physicsBody.velocity = CGVectorMake(startingVelocityX, startingVelocityY);
    
    //start the timer for speed-up
    self.speedupTimer = [NSTimer scheduledTimerWithTimeInterval:kSpeedupInterval
                                     target:self
                                   selector:@selector(speedUpTheBall)
                                   userInfo:nil
                                    repeats:YES];
}

//restart the game when restart node is tapped
-(void)restartTheGame
{
    [self.ballNode removeFromParent];
    //reset timer
    [self.speedupTimer invalidate];
    self.speedupTimer = nil;
    //
    self.isPlayingGame = NO;
    self.startGameInfoNode.hidden = NO;
    self.restartGameNode.hidden = YES;
    //set scores to 0
    self.playerOneScore = 0;
    self.playerTwoScore = 0;
    //update score labels
    [self updateScoreLabels];
}

//update score labels after the score is changed
-(void)updateScoreLabels
{
    self.playerOneScoreNode.text = [NSString stringWithFormat:@"%d",self.playerOneScore];
    self.playerTwoScoreNode.text = [NSString stringWithFormat:@"%d",self.playerTwoScore];
}

-(void)pointForPlayer:(NSInteger)player
{
    switch (player)
    {
        case 1:
            //point for player no 1
            self.playerOneScore++;
            [self.ballNode removeFromParent];
            self.isPlayingGame = NO;
            self.startGameInfoNode.hidden = NO;
            self.restartGameNode.hidden = YES;
            //reset timer
            [self.speedupTimer invalidate];
            self.speedupTimer = nil;
            break;
        case 2:
            //point for player no 2
            self.playerTwoScore++;
            [self.ballNode removeFromParent];
            self.isPlayingGame = NO;
            self.startGameInfoNode.hidden = NO;
            self.restartGameNode.hidden = YES;
            //reset timer
            [self.speedupTimer invalidate];
            self.speedupTimer = nil;
            break;
        default:
            break;
    }
    [self updateScoreLabels];
}

//method that gets called with timer
-(void)speedUpTheBall
{
    CGFloat velocityX = self.ballNode.physicsBody.velocity.dx * kVelocityMultFactor;
    CGFloat velocityY = self.ballNode.physicsBody.velocity.dy * kVelocityMultFactor;
    self.ballNode.physicsBody.velocity = CGVectorMake(velocityX, velocityY);
}

//move the first paddle with data from previous and new touch positions
-(void)moveFirstPaddle
{
    CGPoint previousLocation = [self.playerOnePaddleControlTouch previousLocationInNode:self];
    CGPoint newLocation = [self.playerOnePaddleControlTouch locationInNode:self];
    if (newLocation.x > self.size.width / 2.0)
    {
        //finger is on the other player side
        return;
    }
    CGFloat x = self.playerOnePaddleNode.position.x;
    CGFloat y = self.playerOnePaddleNode.position.y + (newLocation.y - previousLocation.y) * kPaddleMoveMult;
    CGFloat yMax = self.size.height - self.playerOnePaddleNode.size.width/2.0 - self.playerOnePaddleNode.size.height/2.0;
    CGFloat yMin = self.playerOnePaddleNode.size.width/2.0 + self.playerOnePaddleNode.size.height/2.0;
    if (y > yMax)
    {
        y = yMax;
    }
    else if(y < yMin)
    {
        y = yMin;
    }
    self.playerOnePaddleNode.position = CGPointMake(x, y);
}

//move the second paddle with data from previous and new touch positions
-(void)moveSecondPaddle
{
    CGPoint previousLocation = [self.playerTwoPaddleControlTouch previousLocationInNode:self];
    CGPoint newLocation = [self.playerTwoPaddleControlTouch locationInNode:self];
    if (newLocation.x < self.size.width / 2.0)
    {
        //finger is on the other player side
        return;
    }
    CGFloat x = self.playerTwoPaddleNode.position.x;
    CGFloat y = self.playerTwoPaddleNode.position.y + (newLocation.y - previousLocation.y) * kPaddleMoveMult;
    CGFloat yMax = self.size.height - self.playerTwoPaddleNode.size.width/2.0 - self.playerTwoPaddleNode.size.height/2.0;
    CGFloat yMin = self.playerTwoPaddleNode.size.width/2.0 + self.playerTwoPaddleNode.size.height/2.0;
    if (y > yMax)
    {
        y = yMax;
    }
    else if(y < yMin)
    {
        y = yMin;
    }
    self.playerTwoPaddleNode.position = CGPointMake(x, y);
}

//react to contact between nodes/bodies
-(void)didBeginContact:(SKPhysicsContact*)contact
{
    SKPhysicsBody* firstBody;
    SKPhysicsBody* secondBody;
    if (contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask)
    {
        firstBody = contact.bodyA;
        secondBody = contact.bodyB;
    }
    else
    {
        firstBody = contact.bodyB;
        secondBody = contact.bodyA;
    }
    //check if we have ball & corner contact
    if (firstBody.categoryBitMask == ballCategory && secondBody.categoryBitMask == cornerCategory)
    {
        //ball touched left side
        if (firstBody.node.position.x <= firstBody.node.frame.size.width)
        {
            [self pointForPlayer:2];
        }
        //ball touched right side
        else if(firstBody.node.position.x >= (self.size.width - firstBody.node.frame.size.width))
        {
            [self pointForPlayer:1];
        }
    }
    //check if we have ball & paddle contact
    else if (firstBody.categoryBitMask == ballCategory && secondBody.categoryBitMask == paddleCategory)
    {
        //you can react here if you want to customize the ball movement or direction
        NSLog(@"contact of ball and paddle");
    }
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.isPlayingGame) {
        //set touches to move paddles
        for (UITouch *touch in touches)
        {
            CGPoint location = [touch locationInNode:self];
            //first check if restart node is touched
            if (CGRectContainsPoint(self.restartGameNode.frame, location))
            {
                [self restartTheGame];
                return;
            }
            if (self.playerOnePaddleControlTouch == nil)
            {
                if (location.x < self.size.width / 2.0)
                {
                    self.playerOnePaddleControlTouch = touch;
                }
            }
            if (self.playerTwoPaddleControlTouch == nil)
            {
                if (location.x > self.size.width / 2.0)
                {
                    self.playerTwoPaddleControlTouch = touch;
                }
            }
        }
        return;
    }
    else
    {
        //start playing
        [self startPlayingTheGame];
        return;
    }
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    for (UITouch *touch in touches)
    {
        if (touch == self.playerOnePaddleControlTouch)
        {
            [self moveFirstPaddle];
        }
        else if (touch == self.playerTwoPaddleControlTouch)
        {
            [self moveSecondPaddle];
        }
    }
}
-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    NSLog(@"ended %d",touches.count);
    for (UITouch *touch in touches) {
        if (touch == self.playerOnePaddleControlTouch)
        {
            self.playerOnePaddleControlTouch = nil;
        }
        else if (touch == self.playerTwoPaddleControlTouch)
        {
            self.playerTwoPaddleControlTouch = nil;
        }
    }
}

//-(void)update:(CFTimeInterval)currentTime {
//    /* Called before each frame is rendered */
//
//}

@end
