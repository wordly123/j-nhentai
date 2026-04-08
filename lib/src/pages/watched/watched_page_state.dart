import '../../model/search_config.dart';
import '../base/base_page_state.dart';

class WatchedPageState extends BasePageState {
  @override
  String get route => '/watched';

  @override
  SearchConfig searchConfig = SearchConfig(searchType: SearchType.watched);
}
