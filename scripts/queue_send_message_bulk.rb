require 'aws-sdk'
	

# Getting an SQS object
aws_config = {access_key_id: "AKIAJTPGKC25LGKJUCTA", secret_access_key: "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"}
AWS.config(aws_config)

sqs = AWS::SQS.new


failed_remakes = [
["54216b090be0441a1f000002", "4", "54216b090be0441a1f000002_4_1411476363"],
["54216cfe0be0441419000008", "3", "54216cfe0be0441419000008_3_1411476829"],
["54219b6e0be04431b4000004", "4", "54219b6e0be04431b4000004_4_1411488754106"],
["5421b2e20be0443d6a000002", "4", "5421b2e20be0443d6a000002_4_1411494730"],
["5421c1940be0443d6a00000b", "1", "5421c1940be0443d6a00000b_1_1411498474"],
["54223c900be0446913000012", "1", "54223c900be0446913000012_1_1411529959386"],
["54223c900be0446913000012", "3", "54223c900be0446913000012_3_1411530067378"],
["54223c900be0446913000012", "4", "54223c900be0446913000012_4_1411530098583"],
["542243cc0be0440e5b000001", "1", "542243cc0be0440e5b000001_1_1411532298"],
["5422462f0be0440ff8000001", "1", "5422462f0be0440ff8000001_1_1411532406"],
["54224be90be0440ff8000003", "1", "54224be90be0440ff8000003_1_1411533954"],
["54224be90be0440ff8000003", "2", "54224be90be0440ff8000003_2_1411534012"],
["54224be90be0440ff8000003", "3", "54224be90be0440ff8000003_3_1411534043"],
["54224be90be0440ff8000003", "4", "54224be90be0440ff8000003_4_1411534152"],
["54226f8c0be04424de000001", "1", "54226f8c0be04424de000001_1_1411542953"],
["542277850be044292a000001", "1", "542277850be044292a000001_1_1411544978"],
["542277850be044292a000001", "2", "542277850be044292a000001_2_1411544989"],
["542277850be044292a000001", "3", "542277850be044292a000001_3_1411545001"],
["542277850be044292a000001", "4", "542277850be044292a000001_4_1411545014"],
["54227aa50be0442ae0000001", "1", "54227aa50be0442ae0000001_1_1411545776"],
["5422c96c0be0444c6e000004", "1", "5422c96c0be0444c6e000004_1_1411565992"],
["5422ca4c0be0444c6e000005", "1", "5422ca4c0be0444c6e000005_1_1411566290"],
["5422cb050be044545d000001", "1", "5422cb050be044545d000001_1_1411566404"],
["5422cb370be044545d000002", "1", "5422cb370be044545d000002_1_1411566403"],
["5422cb370be044545d000002", "2", "5422cb370be044545d000002_2_1411566416"],
["5422cb370be044545d000002", "3", "5422cb370be044545d000002_3_1411566430"],
["5422ccf80be044545d000003", "1", "5422ccf80be044545d000003_1_1411566869"],
["5422cdfe0be044545d000004", "1", "5422cdfe0be044545d000004_1_1411567126"],
["5422cdfe0be044545d000004", "2", "5422cdfe0be044545d000004_2_1411567147"],
["5422cdfe0be044545d000004", "3", "5422cdfe0be044545d000004_3_1411567172"],
["5422ce6d0be044545d000005", "1", "5422ce6d0be044545d000005_1_1411567226"],
["5422cfa50be044545d000007", "1", "5422cfa50be044545d000007_1_1411567547"],
["5422d1510be0445712000001", "1", "5422d1510be0445712000001_1_1411567983"],
["5422d1510be0445712000001", "2", "5422d1510be0445712000001_2_1411568011"],
["5422d1510be0445712000001", "3", "5422d1510be0445712000001_3_1411568038"],
["5422d8360be04459c0000001", "1", "5422d8360be04459c0000001_1_1411569735"],
["5422d90e0be04459c0000004", "1", "5422d90e0be04459c0000004_1_1411569976"],
["5422d9470be04459c0000005", "1", "5422d9470be04459c0000005_1_1411570021157"],
["5422d9470be04459c0000005", "2", "5422d9470be04459c0000005_2_1411570040729"],
["5422d9470be04459c0000005", "3", "5422d9470be04459c0000005_3_1411570055318"],
["5422e3710be0446225000001", "1", "5422e3710be0446225000001_1_1411572657"],
["5422f3870be04460b2000002", "1", "5422f3870be04460b2000002_1_1411576724"],
["5422f9e10be04460b2000003", "1", "5422f9e10be04460b2000003_1_1411578417"],
["5422fea90be04460b2000005", "1", "5422fea90be04460b2000005_1_1411579190655"],
["5422fea90be04460b2000005", "2", "5422fea90be04460b2000005_2_1411579246218"],
["5422fea90be04460b2000005", "3", "5422fea90be04460b2000005_3_1411579273399"],
["5423018b0be04460b2000007", "1", "5423018b0be04460b2000007_1_1411579983098"],
["5423018b0be04460b2000007", "2", "5423018b0be04460b2000007_2_1411580038612"],
["5423018b0be04460b2000007", "3", "5423018b0be04460b2000007_3_1411580067769"],
["542309c00be0447416000002", "1", "542309c00be0447416000002_1_1411582426598"],
["542309c00be0447416000002", "2", "542309c00be0447416000002_2_1411582468464"],
["542309c00be0447416000002", "3", "542309c00be0447416000002_3_1411582485679"],
["54230b820be0447416000003", "1", "54230b820be0447416000003_1_1411582861"],
["54230b820be0447416000003", "2", "54230b820be0447416000003_2_1411582872"],
["54230b820be0447416000003", "3", "54230b820be0447416000003_3_1411582885"],
["542302450be04460b2000009", "1", "542302450be04460b2000009_1_1411583679"],
["542317380be0447d87000001", "1", "542317380be0447d87000001_1_1411585887"],
["542319230be0447d87000003", "1", "542319230be0447d87000003_1_1411586389"],
["542319230be0447d87000003", "2", "542319230be0447d87000003_2_1411586505"],
["542319230be0447d87000003", "3", "542319230be0447d87000003_3_1411586558"],
["54231a8a0be0447d87000005", "1", "54231a8a0be0447d87000005_1_1411586709"],
["54231a8a0be0447d87000005", "2", "54231a8a0be0447d87000005_2_1411586731"],
["54231a8a0be0447d87000005", "3", "54231a8a0be0447d87000005_3_1411586754"],
["54231d4d0be0447d87000006", "1", "54231d4d0be0447d87000006_1_1411587422"],
["54231d4d0be0447d87000006", "2", "54231d4d0be0447d87000006_2_1411587439"],
["54231d4d0be0447d87000006", "3", "54231d4d0be0447d87000006_3_1411587458"],
["5423219d0be0447d87000007", "1", "5423219d0be0447d87000007_1_1411588520"],
["5423219d0be0447d87000007", "2", "5423219d0be0447d87000007_2_1411588537"],
["54233f9b0be0447d8700000c", "1", "54233f9b0be0447d8700000c_1_1411596215737"],
["542345120be0447d8700000e", "1", "542345120be0447d8700000e_1_1411597607"],
["5423455e0be0447d87000011", "1", "5423455e0be0447d87000011_1_1411597679"],
["5423455c0be0447d87000010", "1", "5423455c0be0447d87000010_1_1411597982"],
["5423455c0be0447d87000010", "2", "5423455c0be0447d87000010_2_1411598040"],
["5423455c0be0447d87000010", "3", "5423455c0be0447d87000010_3_1411598070"],
["5423497e0be04417c9000001", "1", "5423497e0be04417c9000001_1_1411598747"],
["5423497e0be04417c9000001", "2", "5423497e0be04417c9000001_2_1411598780"],
["5423497e0be04417c9000001", "3", "5423497e0be04417c9000001_3_1411599209"],
["5423497e0be04417c9000001", "4", "5423497e0be04417c9000001_4_1411599275"],
["54234bf70be04417c9000002", "1", "54234bf70be04417c9000002_1_1411599382"],
["54234bf70be04417c9000002", "2", "54234bf70be04417c9000002_2_1411599408"],
["54234bf70be04417c9000002", "3", "54234bf70be04417c9000002_3_1411599470"],
["54234bf70be04417c9000002", "4", "54234bf70be04417c9000002_4_1411599674"],
["54234ccd0be04417c9000003", "1", "54234ccd0be04417c9000003_1_1411599732"],
["54234ccd0be04417c9000003", "2", "54234ccd0be04417c9000003_2_1411599750"],
["54234ccd0be04417c9000003", "3", "54234ccd0be04417c9000003_3_1411599779"],
["542355900be0441fa2000001", "1", "542355900be0441fa2000001_1_1411601827"],
["542355900be0441fa2000001", "2", "542355900be0441fa2000001_2_1411601859"],
["542355900be0441fa2000001", "3", "542355900be0441fa2000001_3_1411601894"],
["542355900be0441fa2000001", "4", "542355900be0441fa2000001_4_1411601930"],
["54236b450be0441fa2000005", "1", "54236b450be0441fa2000005_1_1411607379"],
["54236b450be0441fa2000005", "2", "54236b450be0441fa2000005_2_1411607400"],
["54236b450be0441fa2000005", "3", "54236b450be0441fa2000005_3_1411607422"],
["54236bd40be0441fa2000006", "1", "54236bd40be0441fa2000006_1_1411607530"],
["54236bd40be0441fa2000006", "2", "54236bd40be0441fa2000006_2_1411607543"],
["54236bd40be0441fa2000006", "3", "54236bd40be0441fa2000006_3_1411607556"],
["54236bd40be0441fa2000006", "4", "54236bd40be0441fa2000006_4_1411607569"],
["54236c9a0be0442ad3000002", "1", "54236c9a0be0442ad3000002_1_1411607720"],
["54236c9a0be0442ad3000002", "2", "54236c9a0be0442ad3000002_2_1411607741"],
["54236c9a0be0442ad3000002", "3", "54236c9a0be0442ad3000002_3_1411607761"],
["54236e4e0be0442ad3000005", "1", "54236e4e0be0442ad3000005_1_1411867377691"],
["54236e4e0be0442ad3000005", "2", "54236e4e0be0442ad3000005_2_1411867405835"],
["54236e4e0be0442ad3000005", "3", "54236e4e0be0442ad3000005_3_1411867439601"],
["54236e4e0be0442ad3000004", "1", "54236e4e0be0442ad3000004_1_1411867478201"],
["54236e4e0be0442ad3000004", "2", "54236e4e0be0442ad3000004_2_1411867514291"],
["54236e4e0be0442ad3000004", "3", "54236e4e0be0442ad3000004_3_1411867530607"],
["54236fa90be0442ad3000006", "1", "54236fa90be0442ad3000006_1_1411867768855"],
["54236fa90be0442ad3000006", "2", "54236fa90be0442ad3000006_2_1411867787691"],
["54236fa90be0442ad3000006", "3", "54236fa90be0442ad3000006_3_1411867805587"],
["542373390be0442f58000001", "1", "542373390be0442f58000001_1_1411868613706"],
["542373390be0442f58000001", "2", "542373390be0442f58000001_2_1411868646992"],
["542373390be0442f58000001", "3", "542373390be0442f58000001_3_1411868667380"],
["542374540be0442ad3000008", "1", "542374540be0442ad3000008_1_1411609805"],
["542374540be0442ad3000008", "2", "542374540be0442ad3000008_2_1411609871"],
["542374540be0442ad3000008", "3", "542374540be0442ad3000008_3_1411609902"],
["542376e10be0442ad3000009", "1", "542376e10be0442ad3000009_1_1411610398"],
["54238c230be0443257000002", "1", "54238c230be0443257000002_1_1411615803"],
["5423b8e10be044543e000001", "1", "5423b8e10be044543e000001_1_1411627320"],
["5423b8e10be044543e000001", "2", "5423b8e10be044543e000001_2_1411627355"],
["5423bb350be044543e000003", "1", "5423bb350be044543e000003_1_1411627891"],
["5423bb350be044543e000003", "2", "5423bb350be044543e000003_2_1411627914"],
["5423bbca0be044543e000004", "1", "5423bbca0be044543e000004_1_1411627991"],
["5423bc1a0be044571d000001", "1", "5423bc1a0be044571d000001_1_1411628069"],
["5423bc1a0be044571d000001", "2", "5423bc1a0be044571d000001_2_1411628084"],
["5423bc1a0be044571d000001", "3", "5423bc1a0be044571d000001_3_1411628099"],
["5423d07b0be0446250000001", "1", "5423d07b0be0446250000001_1_1411633328"],
["5423e4420be0446250000004", "1", "5423e4420be0446250000004_1_1411638354"]]

# Getting the ProcessFootageQueue
process_footage_queue_url = "https://sqs.us-east-1.amazonaws.com/509268258673/ProcessFootageQueue"
process_footage_queue = sqs.queues[process_footage_queue_url]

puts process_footage_queue.url

for failed_algo in failed_remakes do
	remake_id = failed_algo[0]
	scene_id = failed_algo[1]
	take_id = failed_algo[2]

	message = {remake_id: remake_id, scene_id: scene_id, take_id: take_id}
	process_footage_queue.send_message(message.to_json)
end


