#import <PSTAlertController.h>
#import "BusSuggestionsTable.h"
#import "riobus-Swift.h"

@interface BusSuggestionsTable()

@property (nonatomic) NSString *favoriteLine;
@property (nonatomic) NSMutableArray *recentLines;

@end

@implementation BusSuggestionsTable

static const int favoritesSectionIndex = 0;
static const int recentsSectionIndex = 1;
static const int optionsSectionIndex = 2;
static const int totalSections = 3;
static const int recentItemsLimit = 10;

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        self.rowHeight = 45;
        self.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        self.delegate = self;
        self.dataSource = self;
        
        self.favoriteLine  = [[NSUserDefaults standardUserDefaults] objectForKey:@"favorite_line"];
        
        NSArray *savedRecents = [[NSUserDefaults standardUserDefaults] objectForKey:@"Recents"];
        if (savedRecents) {
            self.recentLines = [savedRecents mutableCopy];
        }
        else {
            self.recentLines = [[NSMutableArray alloc] init];
        }
    }
    
    return self;
}

- (void)syncrhonizePreferences {
    // Trim the size of the recent lines table by removing the last lines
    while (self.recentLines.count >= recentItemsLimit) {
        [self.recentLines removeObjectAtIndex:0];
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:self.recentLines forKey:@"Recents"];
    [[NSUserDefaults standardUserDefaults] setObject:self.favoriteLine forKey:@"favorite_line"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

/**
 * Adiciona uma linha no histórico caso ainda não tenha sido pesquisada.
 * Caso a linha já esteja no histórico, atualiza sua posição para lembrar que 
 * foi a última pesquisada.
 * @param busLine Uma string com o número da linha.
 */
- (void)addToRecentTable:(NSString *)busLine {
    NSIndexPath *recentsIndexPath = [NSIndexPath indexPathForRow:0 inSection:recentsSectionIndex];
    NSIndexPath *optionsIndexPath = [NSIndexPath indexPathForRow:0 inSection:optionsSectionIndex];
    
    @try {
        [self beginUpdates];
        
        if ([self.recentLines containsObject:busLine]) {
            NSInteger index = [self.recentLines indexOfObject:busLine];
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:self.recentLines.count - index - 1 inSection:recentsSectionIndex];
            [self.recentLines removeObject:busLine];
            [self.recentLines addObject:busLine];
            
            [self moveRowAtIndexPath:indexPath toIndexPath:recentsIndexPath];
        }
        else if (![self.favoriteLine isEqualToString:busLine]) {
            [self.recentLines addObject:busLine];
            [self insertRowsAtIndexPaths:@[recentsIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            if (self.recentLines.count == 1) {
                [self insertRowsAtIndexPaths:@[optionsIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        }
        
        [self endUpdates];
    }
    @catch (NSException *e) {
        NSLog(@"Exception atualizando tabela");
    }
    
    [self syncrhonizePreferences];
}

- (void)makeLineFavorite:(UITapGestureRecognizer *)gestureRecognizer {
    NSIndexPath *indexPath = [self indexPathForRowAtPoint:[gestureRecognizer locationInView:self]];
    NSIndexPath *favoriteIndexPath = [NSIndexPath indexPathForRow:0 inSection:favoritesSectionIndex];
    UITableViewCell *cell = [self cellForRowAtIndexPath:indexPath];
    NSString *busLine = cell.textLabel.text;
    
    // Se já existe uma linha favorita definida
    if (self.favoriteLine) {
        PSTAlertController *alertController = [PSTAlertController alertWithTitle:[NSString stringWithFormat:@"Definir a linha %@ como favorita?", busLine] message:[NSString stringWithFormat:@"Isto irá remover a linha %@ dos favoritos.", self.favoriteLine]];
        [alertController addAction:[PSTAlertAction actionWithTitle:@"Cancelar" style:PSTAlertActionStyleCancel handler:nil]];
        [alertController addAction:[PSTAlertAction actionWithTitle:@"Redefinir" style:PSTAlertActionStyleDefault handler:^(PSTAlertAction *action) {
            // Atualizar modelo
            [self.recentLines removeObject:busLine];
            [self.recentLines addObject:self.favoriteLine];
            self.favoriteLine = busLine;
            [self syncrhonizePreferences];
            
            // Atualizar view
            [self beginUpdates];
            NSIndexPath *recentsIndexPath = [NSIndexPath indexPathForRow:0 inSection:recentsSectionIndex];
            [self moveRowAtIndexPath:favoriteIndexPath toIndexPath:recentsIndexPath];
            [self moveRowAtIndexPath:indexPath toIndexPath:favoriteIndexPath];
            [self endUpdates];
            [self configureCell:[self cellForRowAtIndexPath:favoriteIndexPath] forRowAtIndexPath:favoriteIndexPath];
            [self configureCell:[self cellForRowAtIndexPath:recentsIndexPath] forRowAtIndexPath:recentsIndexPath];
        }]];
        
        [alertController showWithSender:self controller:nil animated:YES completion:nil];
    }
    // Caso não exista uma linha favorita já definida
    else {
        // Atualizar modelo
        self.favoriteLine = busLine;
        [self.recentLines removeObject:busLine];
        [self syncrhonizePreferences];
        
        // Atualizar view
        [self beginUpdates];
        [self moveRowAtIndexPath:indexPath toIndexPath:favoriteIndexPath];
        if (self.recentLines.count == 0) {
            [self deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:optionsSectionIndex]] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
        [self endUpdates];
        [self configureCell:[self cellForRowAtIndexPath:favoriteIndexPath] forRowAtIndexPath:favoriteIndexPath];
    }
}

- (void)removeLineFromFavorite:(UITapGestureRecognizer *)gestureRecognizer {
    NSString *confirmMessage = [NSString stringWithFormat:@"Você deseja mesmo remover a linha %@ dos favoritos?", self.favoriteLine];
    PSTAlertController *alertController = [PSTAlertController alertWithTitle:@"Excluir favorito" message:confirmMessage];
    [alertController addAction:[PSTAlertAction actionWithTitle:@"Cancelar" style:PSTAlertActionStyleCancel handler:nil]];
    [alertController addAction:[PSTAlertAction actionWithTitle:@"Excluir" style:PSTAlertActionStyleDefault handler:^(PSTAlertAction *action) {
        // Atualizar modelo
        if (self.favoriteLine) {
            [self.recentLines addObject:self.favoriteLine];
        }
        self.favoriteLine = nil;
        [self syncrhonizePreferences];
        
        // Atualizar view
        NSIndexPath *favoriteIndexPath = [NSIndexPath indexPathForRow:0 inSection:favoritesSectionIndex];
        NSIndexPath *recentsIndexPath = [NSIndexPath indexPathForRow:0 inSection:recentsSectionIndex];
        NSIndexPath *optionsIndexPath = [NSIndexPath indexPathForRow:0 inSection:optionsSectionIndex];

        [self beginUpdates];
        [self moveRowAtIndexPath:favoriteIndexPath toIndexPath:recentsIndexPath];
        if (self.recentLines.count == 1) {
            [self insertRowsAtIndexPaths:@[optionsIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
        [self endUpdates];
        [self configureCell:[self cellForRowAtIndexPath:recentsIndexPath] forRowAtIndexPath:recentsIndexPath];
    }]];
    
    [alertController showWithSender:self controller:nil animated:YES completion:nil];
}

- (void)clearRecentSearches {
    PSTAlertController *alertController = [PSTAlertController alertWithTitle:@"Limpar histórico" message:@"Deseja mesmo excluir todas as linhas recentes?"];
    [alertController addAction:[PSTAlertAction actionWithTitle:@"Cancelar" style:PSTAlertActionStyleCancel handler:nil]];
    [alertController addAction:[PSTAlertAction actionWithTitle:@"Excluir" style:PSTAlertActionStyleDefault handler:^(PSTAlertAction *action) {
        NSInteger recentsToDelete = self.recentLines.count;
        
        // Atualizar modelo
        [self.recentLines removeAllObjects];
        [self syncrhonizePreferences];
        
        // Atualizar view
        [self beginUpdates];

        NSMutableArray *rowsToDelete = [NSMutableArray arrayWithCapacity:recentsToDelete];
        for (int i=0; i<recentsToDelete; i++) {
            [rowsToDelete addObject:[NSIndexPath indexPathForRow:i inSection:recentsSectionIndex]];
        }
        [rowsToDelete addObject:[NSIndexPath indexPathForRow:0 inSection:optionsSectionIndex]];
        [self deleteRowsAtIndexPaths:rowsToDelete withRowAnimation:UITableViewRowAnimationFade];
        [self endUpdates];
    }]];
    
    [alertController showWithSender:self controller:nil animated:YES completion:nil];
}


#pragma mark UITableViewDataSource methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return totalSections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == favoritesSectionIndex) {
        return self.favoriteLine != nil;
    }
    
    if (section == recentsSectionIndex) {
        return self.recentLines.count;
    }
    
    if (section == optionsSectionIndex) {
        return self.recentLines.count > 0;
    }
    
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *simpleTableIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:simpleTableIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:simpleTableIdentifier];
    }
    
    cell.imageView.userInteractionEnabled = YES;
    cell.imageView.tag = indexPath.item;

    [self configureCell:cell forRowAtIndexPath:indexPath];
    
    return cell;
}

- (void)configureCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == favoritesSectionIndex) {
        cell.imageView.image = [[UIImage imageNamed:@"StarFilled"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        cell.tintColor = [UIColor appGoldColor];
        cell.textLabel.text = self.favoriteLine;
        cell.textLabel.textColor = [UIColor darkGrayColor];
        UITapGestureRecognizer *tapped = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(removeLineFromFavorite:)];
        tapped.numberOfTapsRequired = 1;
        [cell.imageView addGestureRecognizer:tapped];
    }
    else if (indexPath.section == recentsSectionIndex) {
        cell.imageView.image = [[UIImage imageNamed:@"Star"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        cell.tintColor = [UIColor colorWithWhite:0.8 alpha:1.0];
        cell.textLabel.text = self.recentLines[self.recentLines.count - indexPath.row - 1];
        cell.textLabel.textColor = [UIColor darkGrayColor];
        UITapGestureRecognizer *tapped = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(makeLineFavorite:)];
        tapped.numberOfTapsRequired = 1;
        [cell.imageView addGestureRecognizer:tapped];
    }
    else if (indexPath.section == optionsSectionIndex) {
        cell.imageView.image = nil;
        cell.textLabel.text = @"Limpar pesquisas";
        cell.textLabel.textColor = [UIColor lightGrayColor];
    }
    cell.imageView.isAccessibilityElement = YES;
    cell.imageView.accessibilityTraits = UIAccessibilityTraitButton;
    if ([cell respondsToSelector:NSSelectorFromString(@"setAcessibilityElements")]) {
        cell.accessibilityElements = @[cell.textLabel, cell.imageView];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section != optionsSectionIndex;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Atualizar modelo
        if (indexPath.section == favoritesSectionIndex) {
            self.favoriteLine = nil;
        }
        else {
            [self.recentLines removeObjectAtIndex:self.recentLines.count - indexPath.row - 1];
        }
        [self syncrhonizePreferences];
        
        // Atualizar view
        [tableView beginUpdates];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        if (indexPath.section == recentsSectionIndex && self.recentLines.count == 0) {
            [tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:optionsSectionIndex]] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
        [tableView endUpdates];
    }
}


#pragma mark UITableViewDelegate methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (self.searchInput) {
        if (indexPath.section == favoritesSectionIndex) {
            (self.searchInput).text = self.favoriteLine;
            [self.searchInput.delegate searchBarSearchButtonClicked:self.searchInput];
        }
        else if (indexPath.section == recentsSectionIndex) {
            (self.searchInput).text = self.recentLines[self.recentLines.count - indexPath.row - 1];
            [self.searchInput.delegate searchBarSearchButtonClicked:self.searchInput];
        }
        else if (indexPath.section == optionsSectionIndex) {
            [self clearRecentSearches];
        }
    }
}

//- (nullable NSString *)tableView:(nonnull UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
//    if (section == favoritesSectionIndex && self.favoriteLine) {
//        return @"Linha favorita";
//    }
//    else if (section == recentsSectionIndex && self.recentLines.count > 0) {
//        return @"Pesquisas recentes";
//    }
//    
//    return @"";
//}

@end
