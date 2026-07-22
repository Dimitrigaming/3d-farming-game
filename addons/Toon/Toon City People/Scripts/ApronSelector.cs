using System.Collections.Generic;
using UnityEngine;

namespace ApronSelector
{

    public class ApronSelector : MonoBehaviour
    {
        public const int MAXIMUM_NUMBER_APRONS = 5
;
        [Range(0, MAXIMUM_NUMBER_APRONS - 1)]
        public int Apron;
        public GameObject[] Aprons = new GameObject[MAXIMUM_NUMBER_APRONS];


        void OnValidate()
        {
		ValidateObject(Apron, Aprons);

        }

        public void ValidateObject(int selectedIndex, GameObject[] objects)
        {
            if (selectedIndex > objects.Length)
                selectedIndex = objects.Length;

            for (int i = 0; i < objects.Length; i++)
            {
                if (objects[i] != null)
                    objects[i].SetActive(i == selectedIndex);
            }
        }
    }
}
