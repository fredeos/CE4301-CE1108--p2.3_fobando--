traigase "prueba1.f"
#int global_result;

func int main(){
    int nums[4];
    int i = 0;
    int total = 0;
    #float y = 0;

    nums[0] = 1;
    nums[1] = 2;
    nums[2] = 3;
    nums[3] = 4;

    llenar(nums);
    total = sumar4(nums);

    for (int j = 0; j += 1; j < 4) {
        total += nums[j];
    }

    while (i < 2) {
        total += mezclar(i, total, 3);
        i += 1;
    }

    if (total > 50) {
        global_result = total;
    } elif (total == 50) {
        global_result = 50;
    } else {
        global_result = 0;
    }
    ret global_result;
}
