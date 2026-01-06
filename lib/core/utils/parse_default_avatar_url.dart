
import '../ui/chaput_circle_avatar/data/default_avatar_url_model.dart';

DefaultAvatarUrl parseDefaultAvatarUrl(String inputString){
  List<String> parts = inputString.split('/');

  if( parts.length != 3 ){
    return DefaultAvatarUrl(isInvalidUrl: true, backgroundPath: '', avatarPath: '');
  }

  String typeString = parts[0].toLowerCase();

  String type = typeString == 'm'
      ? 'male' : typeString == 'f'
      ? 'female' : 'pet';
  String backdroundId = parts[1];
  String avatarId = parts[2];

  String backgroundPath = 'assets/images/avatar_assets/background/$backdroundId.jpg';
  String avatarPath = 'assets/images/avatar_assets/$type/$avatarId.png';

  return DefaultAvatarUrl(isInvalidUrl: false, backgroundPath: backgroundPath, avatarPath: avatarPath);
}