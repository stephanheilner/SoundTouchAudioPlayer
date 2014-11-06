//
// Copyright 2011 Mike Coleman
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// Note: You are NOT required to make the license available from within your
// iOS application. Including it in your project is sufficient.
//
// Attribution is not required, but appreciated :)
//

#import "AudioQueuePlayer.h"

#define NUM_AUDIO_BUFFERS 3

@interface AudioQueuePlayer() {
    AudioStreamBasicDescription audioDesc;
    AudioQueueRef audioQueue;
    AudioQueueBufferRef audioBuffers[NUM_AUDIO_BUFFERS];
    BOOL m_running;
}

- (void)setupAudioFormat;
- (void)cleanupAudioQueue;
- (void)makeAudioQueue;
- (void)makeBuffers;
- (void)handleQueuePropertyChange:(AudioQueueRef)inAQ propertyID:(AudioQueuePropertyID)inID;

@end

@implementation AudioQueuePlayer

@synthesize addSampleCallback;
@synthesize delegate;

- (BOOL)running {
    return m_running;
}

static void MyAudioQueuePropertyListenerProc(void *inUserData, AudioQueueRef inAQ, AudioQueuePropertyID inID) {
    AudioQueuePlayer *player = (AudioQueuePlayer *)inUserData;
    [player handleQueuePropertyChange:inAQ propertyID:inID];
}

static void HandleOutputBuffer(void *inData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) {
    OSStatus err = noErr;
    AudioQueuePlayer *player = (AudioQueuePlayer *)inData;
    if (player == nil) {
        NSLog(@"nil player!");
        return;
    }
    NSLog(@"%s: running = %d, addSampleCallback %@", __func__, player->m_running, player.addSampleCallback ? @"present" : @"missing");
    if (player->m_running && player.addSampleCallback) {
        inBuffer->mAudioDataByteSize = 0;
        (player.addSampleCallback)(player, inBuffer);
        if (inBuffer->mAudioDataByteSize) {
            NSLog(@"enqueue");
            err = AudioQueueEnqueueBuffer(player->audioQueue, inBuffer, 0, 0);
        }
    }
    else {
        NSLog(@"%s: stopping audio queue", __func__);
        err = AudioQueueStop(player->audioQueue, NO);
    }
}

- (id)init {
    self = [super init];
    if (self) {
        m_running = NO;
    }
    return self;
}

- (void)dealloc {
    delegate = nil;
    [super dealloc];
}

- (void)setupAudioFormat {
    audioDesc.mSampleRate = 44100.00;
    audioDesc.mFormatID = kAudioFormatLinearPCM;
    audioDesc.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved;
    audioDesc.mChannelsPerFrame = 2;

    audioDesc.mFramesPerPacket = 1;
    audioDesc.mBitsPerChannel = 16;
    audioDesc.mBytesPerPacket = 4;
    audioDesc.mBytesPerFrame = 4;
    //ok canonicial implies interleaved, 2 channels, 16 bits per channel == 32 bits == 4 bytesPerFrame/Packet
    //TODO why isnt this ABSD populated from the file selected?
    //TODO using AudioFileGetProperty, kAudioFilePropertyDataFormat?

}

- (void)cleanupAudioQueue {
    if (audioQueue != NULL) {
        AudioQueueDispose(audioQueue, true);
    }
    audioQueue = NULL;
}

- (void)makeAudioQueue {
    OSStatus err;
    [self cleanupAudioQueue];
    err = AudioQueueNewOutput(&audioDesc, HandleOutputBuffer, self,
            CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &audioQueue);
            NSAssert(err == noErr, @"expected noErr", err);
    err = AudioQueueAddPropertyListener(audioQueue, kAudioQueueProperty_IsRunning, MyAudioQueuePropertyListenerProc, self);
            NSAssert(err == noErr, @"expected noErr", err);
}

- (void)makeBuffers {
    OSStatus err;
    for (int i = 0; i < NUM_AUDIO_BUFFERS; ++i) {
        err = AudioQueueAllocateBufferWithPacketDescriptions(audioQueue, 32768, 0, &audioBuffers[i]);
                NSAssert(err == noErr, @"expected noErr", err);
        HandleOutputBuffer(self, audioQueue, audioBuffers[i]);
    }
}

- (void)start {
    OSStatus err = noErr;
    m_running = YES;
    [self setupAudioFormat];
    [self makeAudioQueue];
    [self makeBuffers];
    err = AudioQueueStart(audioQueue, NULL);
            NSAssert(err == noErr, @"expected noErr", err);
    NSLog(@"leaving %s", __func__);
}

- (void)stop {
    OSStatus err = noErr;
    m_running = NO;
    if (audioQueue) {
        err = AudioQueueStop(audioQueue, NO);
                NSAssert(err == noErr, @"expected noErr", err);
    }
}

- (void)handleQueuePropertyChange:(AudioQueueRef)inAQ propertyID:(AudioQueuePropertyID)inID; {
    if (delegate) {
        switch (inID) {
            case kAudioQueueProperty_IsRunning: {
                UInt32 isRunning;
                UInt32 ioDataSize = sizeof(isRunning);
                AudioQueueGetProperty(inAQ, inID, &isRunning, &ioDataSize);
                if (isRunning) {
                    if ([delegate respondsToSelector:@selector(audioQueuePlayerDidStartPlayback:)]) {
                        [delegate audioQueuePlayerDidStartPlayback:self];
                    }
                }
                else {
                    if ([delegate respondsToSelector:@selector(audioQueuePlayerDidStopPlayback:)]) {
                        [delegate audioQueuePlayerDidStopPlayback:self];
                    }
                }
            }
                break;

            default:
                break;
        }
    }
}
@end
