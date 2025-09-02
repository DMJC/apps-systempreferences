#import "NetworkModule.h"

@implementation NetworkModule

- (void)dealloc {
    [super dealloc];
}

- (void)mainViewDidLoad {
    [super mainViewDidLoad];
    [self setupUI];
}

#pragma mark - UI Setup

- (void)setupUI {
    NSView *contentView = [self mainView];
    CGFloat width = contentView.bounds.size.width;
    // Set up the main view frame
    self.mainView.frame = NSMakeRect(0, 0, 400, 300);
}

- (void)ApplyButtonPressed:(NSButton *)sender {
    NSLog(@"Apply Button Pressed");
}

@end
